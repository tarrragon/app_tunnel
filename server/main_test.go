package main

import (
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"
	"time"
)

// newTestHandler 建一個假 ttyd 後端 + 認證閘道,供測試。
func newTestHandler(t *testing.T, token string, upstream http.HandlerFunc) http.Handler {
	t.Helper()
	ttyd := httptest.NewServer(upstream)
	t.Cleanup(ttyd.Close)
	target, err := url.Parse(ttyd.URL)
	if err != nil {
		t.Fatal(err)
	}
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	return authProxyHandler([]byte(token), target, 2*time.Second, logger)
}

func TestAuthGate_NoToken_404(t *testing.T) {
	h := newTestHandler(t, "secret", func(w http.ResponseWriter, r *http.Request) {
		t.Error("無 token 不該轉發到 ttyd")
	})
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/ws", nil))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("want 404, got %d", rec.Code)
	}
}

func TestAuthGate_WrongToken_404(t *testing.T) {
	h := newTestHandler(t, "secret", func(w http.ResponseWriter, r *http.Request) {
		t.Error("錯 token 不該轉發到 ttyd")
	})
	req := httptest.NewRequest(http.MethodGet, "/ws", nil)
	req.Header.Set(tokenHeader, "wrong")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusNotFound {
		t.Fatalf("want 404, got %d", rec.Code)
	}
}

func TestAuthGate_GoodToken_Forwarded_AndStripsToken(t *testing.T) {
	h := newTestHandler(t, "secret", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get(tokenHeader) != "" {
			t.Error("通過後本機 token 不該上傳給 ttyd")
		}
		w.WriteHeader(http.StatusNoContent)
	})
	req := httptest.NewRequest(http.MethodGet, "/ws", nil)
	req.Header.Set(tokenHeader, "secret")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusNoContent {
		t.Fatalf("want 204, got %d", rec.Code)
	}
}

func TestClientIP_PrefersCFHeader(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.RemoteAddr = "127.0.0.1:5555"
	req.Header.Set("Cf-Connecting-Ip", "203.0.113.9")
	if got := clientIP(req); got != "203.0.113.9" {
		t.Fatalf("want CF-Connecting-Ip, got %q", got)
	}
}

func TestClientIP_FallsBackToRemoteAddr(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.RemoteAddr = "127.0.0.1:5555"
	if got := clientIP(req); got != "127.0.0.1:5555" {
		t.Fatalf("want RemoteAddr, got %q", got)
	}
}
