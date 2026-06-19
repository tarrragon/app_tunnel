package main

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"time"
)

// -- Proxy + Enroll Integration (real HTTP connections) --

// TestIntegration_ProxyRealHTTP verifies transparent forwarding over real TCP.
func TestIntegration_ProxyRealHTTP(t *testing.T) {
	ttyd := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Ttyd", "real")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ttyd-real-response"))
	}))
	defer ttyd.Close()

	target, err := url.Parse(ttyd.URL)
	if err != nil {
		t.Fatal(err)
	}
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	handler := proxyHandler(target, 2*time.Second, logger)

	proxySrv := httptest.NewServer(handler)
	defer proxySrv.Close()

	resp, err := http.Get(proxySrv.URL + "/ws")
	if err != nil {
		t.Fatalf("real HTTP GET failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("want 200, got %d", resp.StatusCode)
	}
	body, _ := io.ReadAll(resp.Body)
	if string(body) != "ttyd-real-response" {
		t.Fatalf("want ttyd-real-response, got %q", string(body))
	}
}

// TestIntegration_ProxyPreservesHeaders verifies Authorization header forwarding over real TCP.
func TestIntegration_ProxyPreservesHeaders(t *testing.T) {
	var gotAuth string
	ttyd := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotAuth = r.Header.Get("Authorization")
		w.WriteHeader(http.StatusNoContent)
	}))
	defer ttyd.Close()

	target, _ := url.Parse(ttyd.URL)
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	proxySrv := httptest.NewServer(proxyHandler(target, 2*time.Second, logger))
	defer proxySrv.Close()

	req, _ := http.NewRequest(http.MethodGet, proxySrv.URL+"/ws", nil)
	req.Header.Set("Authorization", "Basic dXNlcjpwYXNz")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	resp.Body.Close()

	if gotAuth != "Basic dXNlcjpwYXNz" {
		t.Fatalf("Authorization not forwarded: got %q", gotAuth)
	}
}

// TestIntegration_EnrollBuildBundle verifies enroll bundle round-trips through JSON.
func TestIntegration_EnrollBuildBundle(t *testing.T) {
	b := buildBundle("http://100.64.0.1:8080/ws", "admin", "secret123")
	data, err := json.Marshal(b)
	if err != nil {
		t.Fatalf("marshal failed: %v", err)
	}

	var decoded bundle
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("unmarshal failed: %v", err)
	}
	if decoded.V != 2 {
		t.Errorf("V: want 2, got %d", decoded.V)
	}
	if decoded.Endpoint != "http://100.64.0.1:8080/ws" {
		t.Errorf("Endpoint mismatch: %q", decoded.Endpoint)
	}
	if decoded.TtydUser != "admin" || decoded.TtydPass != "secret123" {
		t.Errorf("credentials mismatch: user=%q pass=%q", decoded.TtydUser, decoded.TtydPass)
	}
}

// -- WebSocket Upgrade Transparent Forwarding --

// TestIntegration_WSUpgradeForwarded verifies that WS upgrade requests reach the backend
// with correct headers. We use a plain HTTP handler that checks upgrade headers
// (real WS handshake requires a WS server, but transparent proxy preserves headers).
func TestIntegration_WSUpgradeForwarded(t *testing.T) {
	var receivedUpgrade, receivedConnection string
	ttyd := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		receivedUpgrade = r.Header.Get("Upgrade")
		receivedConnection = r.Header.Get("Connection")
		// Respond 101 to simulate upgrade acknowledgment (simplified).
		w.WriteHeader(http.StatusSwitchingProtocols)
	}))
	defer ttyd.Close()

	target, _ := url.Parse(ttyd.URL)
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	proxySrv := httptest.NewServer(proxyHandler(target, 2*time.Second, logger))
	defer proxySrv.Close()

	req, _ := http.NewRequest(http.MethodGet, proxySrv.URL+"/ws", nil)
	req.Header.Set("Upgrade", "websocket")
	req.Header.Set("Connection", "Upgrade")
	req.Header.Set("Sec-WebSocket-Key", "dGhlIHNhbXBsZSBub25jZQ==")
	req.Header.Set("Sec-WebSocket-Version", "13")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("WS upgrade request failed: %v", err)
	}
	resp.Body.Close()

	if !strings.EqualFold(receivedUpgrade, "websocket") {
		t.Errorf("Upgrade header not forwarded: got %q", receivedUpgrade)
	}
	if !strings.Contains(strings.ToLower(receivedConnection), "upgrade") {
		t.Errorf("Connection header not forwarded: got %q", receivedConnection)
	}
}

// -- WebSocket Upgrade Log Verification --

func TestIntegration_WSUpgradeSuccess_Logged(t *testing.T) {
	ttyd := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.EqualFold(r.Header.Get("Upgrade"), "websocket") {
			hj, ok := w.(http.Hijacker)
			if !ok {
				t.Fatal("upstream does not support hijack")
			}
			conn, bufrw, err := hj.Hijack()
			if err != nil {
				t.Fatal(err)
			}
			bufrw.WriteString("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n")
			bufrw.Flush()
			conn.Close()
			return
		}
		w.WriteHeader(http.StatusOK)
	}))
	defer ttyd.Close()

	target, _ := url.Parse(ttyd.URL)
	var logBuf bytes.Buffer
	logger := slog.New(slog.NewTextHandler(&logBuf, &slog.HandlerOptions{Level: slog.LevelDebug}))
	proxySrv := httptest.NewServer(proxyHandler(target, 2*time.Second, logger))
	defer proxySrv.Close()

	req, _ := http.NewRequest(http.MethodGet, proxySrv.URL+"/ws", nil)
	req.Header.Set("Upgrade", "websocket")
	req.Header.Set("Connection", "Upgrade")
	req.Header.Set("Sec-WebSocket-Key", "dGhlIHNhbXBsZSBub25jZQ==")
	req.Header.Set("Sec-WebSocket-Version", "13")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("WS upgrade request failed: %v", err)
	}
	resp.Body.Close()

	if resp.StatusCode != http.StatusSwitchingProtocols {
		t.Fatalf("want 101, got %d", resp.StatusCode)
	}
	logged := logBuf.String()
	if !strings.Contains(logged, "ws upgrade succeeded") {
		t.Fatalf("expected 'ws upgrade succeeded' in log, got:\n%s", logged)
	}
	if !strings.Contains(logged, "upstream_status=101") {
		t.Fatalf("expected upstream_status=101 in log, got:\n%s", logged)
	}
}

func TestIntegration_WSUpgradeFail_Logged(t *testing.T) {
	ttyd := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusForbidden)
	}))
	defer ttyd.Close()

	target, _ := url.Parse(ttyd.URL)
	var logBuf bytes.Buffer
	logger := slog.New(slog.NewTextHandler(&logBuf, &slog.HandlerOptions{Level: slog.LevelDebug}))
	proxySrv := httptest.NewServer(proxyHandler(target, 2*time.Second, logger))
	defer proxySrv.Close()

	req, _ := http.NewRequest(http.MethodGet, proxySrv.URL+"/ws", nil)
	req.Header.Set("Upgrade", "websocket")
	req.Header.Set("Connection", "Upgrade")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	resp.Body.Close()

	if resp.StatusCode != http.StatusForbidden {
		t.Fatalf("want 403, got %d", resp.StatusCode)
	}
	logged := logBuf.String()
	if !strings.Contains(logged, "ws upgrade failed") {
		t.Fatalf("expected 'ws upgrade failed' in log, got:\n%s", logged)
	}
	if !strings.Contains(logged, "upstream_status=403") {
		t.Fatalf("expected upstream_status=403 in log, got:\n%s", logged)
	}
}

// -- Graceful Shutdown --

// TestIntegration_GracefulShutdown verifies that the server stops accepting new
// connections after shutdown while completing in-flight requests.
func TestIntegration_GracefulShutdown(t *testing.T) {
	ttyd := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	}))
	defer ttyd.Close()

	target, _ := url.Parse(ttyd.URL)
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	handler := proxyHandler(target, 2*time.Second, logger)

	// Start a real server on a random port.
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	addr := listener.Addr().String()

	srv := &http.Server{Handler: handler}
	go srv.Serve(listener)

	// Verify server is up.
	resp, err := http.Get("http://" + addr + "/")
	if err != nil {
		t.Fatalf("server not reachable: %v", err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("want 200 before shutdown, got %d", resp.StatusCode)
	}

	// Graceful shutdown.
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		t.Fatalf("shutdown failed: %v", err)
	}

	// After shutdown, new connections should fail.
	_, err = http.Get("http://" + addr + "/")
	if err == nil {
		t.Fatal("expected connection refused after shutdown, but request succeeded")
	}
}

// -- Audit Log Event Verification --

// TestIntegration_AuditLogEvents verifies that proxy emits structured audit log
// entries with required fields (client_ip, path, websocket).
func TestIntegration_AuditLogEvents(t *testing.T) {
	ttyd := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))
	defer ttyd.Close()

	target, _ := url.Parse(ttyd.URL)

	var logBuf bytes.Buffer
	logger := slog.New(slog.NewJSONHandler(&logBuf, nil))
	handler := proxyHandler(target, 2*time.Second, logger)

	proxySrv := httptest.NewServer(handler)
	defer proxySrv.Close()

	// Regular HTTP request.
	resp, err := http.Get(proxySrv.URL + "/some/path")
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	resp.Body.Close()

	// WS upgrade request.
	req, _ := http.NewRequest(http.MethodGet, proxySrv.URL+"/ws", nil)
	req.Header.Set("Upgrade", "websocket")
	req.Header.Set("Connection", "Upgrade")
	resp2, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("ws request failed: %v", err)
	}
	resp2.Body.Close()

	// Parse log lines and verify audit events.
	lines := strings.Split(strings.TrimSpace(logBuf.String()), "\n")
	var auditEvents []map[string]interface{}
	for _, line := range lines {
		var entry map[string]interface{}
		if err := json.Unmarshal([]byte(line), &entry); err != nil {
			continue
		}
		if msg, ok := entry["msg"]; ok && msg == "connection accepted" {
			auditEvents = append(auditEvents, entry)
		}
	}

	if len(auditEvents) < 2 {
		t.Fatalf("want at least 2 audit events, got %d; log:\n%s", len(auditEvents), logBuf.String())
	}

	// First event: regular HTTP.
	ev0 := auditEvents[0]
	if _, ok := ev0["client_ip"]; !ok {
		t.Error("audit event missing client_ip")
	}
	if path, ok := ev0["path"].(string); !ok || path != "/some/path" {
		t.Errorf("audit event path: want /some/path, got %v", ev0["path"])
	}
	if ws, ok := ev0["websocket"].(bool); !ok || ws {
		t.Errorf("audit event websocket: want false, got %v", ev0["websocket"])
	}

	// Second event: WS upgrade.
	ev1 := auditEvents[1]
	if path, ok := ev1["path"].(string); !ok || path != "/ws" {
		t.Errorf("audit event path: want /ws, got %v", ev1["path"])
	}
	if ws, ok := ev1["websocket"].(bool); !ok || !ws {
		t.Errorf("audit event websocket: want true, got %v", ev1["websocket"])
	}
}

// TestIntegration_AuditLogBackendError verifies audit log for ttyd backend failures.
func TestIntegration_AuditLogBackendError(t *testing.T) {
	target, _ := url.Parse("http://127.0.0.1:1") // unreachable

	var logBuf bytes.Buffer
	logger := slog.New(slog.NewJSONHandler(&logBuf, nil))
	handler := proxyHandler(target, 1*time.Second, logger)

	proxySrv := httptest.NewServer(handler)
	defer proxySrv.Close()

	resp, err := http.Get(proxySrv.URL + "/ws")
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	resp.Body.Close()

	if resp.StatusCode != http.StatusBadGateway {
		t.Fatalf("want 502, got %d", resp.StatusCode)
	}

	// Verify error log entry exists.
	lines := strings.Split(strings.TrimSpace(logBuf.String()), "\n")
	var hasErrorLog bool
	for _, line := range lines {
		var entry map[string]interface{}
		if err := json.Unmarshal([]byte(line), &entry); err != nil {
			continue
		}
		if level, ok := entry["level"].(string); ok && level == "ERROR" {
			hasErrorLog = true
			if _, ok := entry["err"]; !ok {
				t.Error("error log missing err field")
			}
			if _, ok := entry["client_ip"]; !ok {
				t.Error("error log missing client_ip field")
			}
		}
	}
	if !hasErrorLog {
		t.Errorf("no ERROR level log found; log:\n%s", logBuf.String())
	}
}
