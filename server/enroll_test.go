package main

import "testing"

func TestNewToken_Length64Hex(t *testing.T) {
	tok := newToken()
	if len(tok) != 64 {
		t.Fatalf("want 64 hex chars (32 bytes), got %d", len(tok))
	}
}

func TestNewToken_Unique(t *testing.T) {
	if newToken() == newToken() {
		t.Fatal("兩次產生的密鑰不該相同")
	}
}

func TestBuildBundle(t *testing.T) {
	b := buildBundle("wss://term.example.com/ws", "cfid", "cfsec", "tok", "u", "p")
	if b.V != 1 {
		t.Errorf("V: want 1, got %d", b.V)
	}
	if b.Protocol != "ttyd-tty/v1" {
		t.Errorf("Protocol: want ttyd-tty/v1, got %q", b.Protocol)
	}
	if b.Endpoint != "wss://term.example.com/ws" {
		t.Errorf("Endpoint mismatch: %q", b.Endpoint)
	}
	if b.ProxyToken != "tok" {
		t.Errorf("ProxyToken: want tok, got %q", b.ProxyToken)
	}
	if b.CFAccessID != "cfid" || b.CFAccessSecret != "cfsec" {
		t.Errorf("CF Access 欄位 mismatch")
	}
}
