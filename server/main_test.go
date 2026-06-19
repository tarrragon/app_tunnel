package main

import (
	"bytes"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"time"
)

// newTestHandler 建一個假 ttyd 後端 + 透明 proxy,供測試。
func newTestHandler(t *testing.T, upstream http.HandlerFunc) http.Handler {
	t.Helper()
	ttyd := httptest.NewServer(upstream)
	t.Cleanup(ttyd.Close)
	target, err := url.Parse(ttyd.URL)
	if err != nil {
		t.Fatal(err)
	}
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	return proxyHandler(target, 2*time.Second, logger)
}

func TestProxy_TransparentForward(t *testing.T) {
	h := newTestHandler(t, func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ttyd-ok"))
	})
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/ws", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("want 200, got %d", rec.Code)
	}
	if rec.Body.String() != "ttyd-ok" {
		t.Fatalf("want ttyd-ok, got %q", rec.Body.String())
	}
}

func TestProxy_PreservesAuthorizationHeader(t *testing.T) {
	h := newTestHandler(t, func(w http.ResponseWriter, r *http.Request) {
		if got := r.Header.Get("Authorization"); got == "" {
			t.Error("Authorization header 應原樣轉發給 ttyd")
		}
		w.WriteHeader(http.StatusNoContent)
	})
	req := httptest.NewRequest(http.MethodGet, "/ws", nil)
	req.Header.Set("Authorization", "Basic dXNlcjpwYXNz")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusNoContent {
		t.Fatalf("want 204, got %d", rec.Code)
	}
}

func TestProxy_BackendDown_502(t *testing.T) {
	// 指向一個不存在的後端。
	target, _ := url.Parse("http://127.0.0.1:1")
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	h := proxyHandler(target, 1*time.Second, logger)

	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/", nil))
	if rec.Code != http.StatusBadGateway {
		t.Fatalf("want 502, got %d", rec.Code)
	}
}

func newTestHandlerWithLog(t *testing.T, upstream http.HandlerFunc) (http.Handler, *bytes.Buffer) {
	t.Helper()
	ttyd := httptest.NewServer(upstream)
	t.Cleanup(ttyd.Close)
	target, err := url.Parse(ttyd.URL)
	if err != nil {
		t.Fatal(err)
	}
	var buf bytes.Buffer
	logger := slog.New(slog.NewTextHandler(&buf, &slog.HandlerOptions{Level: slog.LevelDebug}))
	return proxyHandler(target, 2*time.Second, logger), &buf
}

func TestProxy_WSUpgradeFail_Logged(t *testing.T) {
	h, buf := newTestHandlerWithLog(t, func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusForbidden)
	})
	req := httptest.NewRequest(http.MethodGet, "/ws", nil)
	req.Header.Set("Upgrade", "websocket")
	req.Header.Set("Connection", "Upgrade")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if rec.Code != http.StatusForbidden {
		t.Fatalf("want 403, got %d", rec.Code)
	}
	logged := buf.String()
	if !strings.Contains(logged, "ws upgrade failed") {
		t.Fatalf("expected 'ws upgrade failed' in log, got:\n%s", logged)
	}
	if !strings.Contains(logged, "upstream_status=403") {
		t.Fatalf("expected upstream_status=403 in log, got:\n%s", logged)
	}
}

func TestProxy_NonWSRequest_NoUpgradeLog(t *testing.T) {
	h, buf := newTestHandlerWithLog(t, func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/", nil))

	logged := buf.String()
	if strings.Contains(logged, "ws upgrade") {
		t.Fatalf("non-WS request should not log ws upgrade, got:\n%s", logged)
	}
}

func TestIsWebSocketUpgrade(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/ws", nil)
	if isWebSocketUpgrade(req) {
		t.Fatal("無 Upgrade header 不應回傳 true")
	}
	req.Header.Set("Upgrade", "websocket")
	if !isWebSocketUpgrade(req) {
		t.Fatal("有 Upgrade: websocket 應回傳 true")
	}
}
