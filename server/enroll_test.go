package main

import (
	"encoding/json"
	"testing"
)

func TestBuildBundle(t *testing.T) {
	b := buildBundle("http://100.64.0.1:7681/ws", "u", "p")
	if b.V != 2 {
		t.Errorf("V: want 2, got %d", b.V)
	}
	if b.Protocol != "ttyd-tty/v1" {
		t.Errorf("Protocol: want ttyd-tty/v1, got %q", b.Protocol)
	}
	if b.Endpoint != "http://100.64.0.1:7681/ws" {
		t.Errorf("Endpoint mismatch: %q", b.Endpoint)
	}
	if b.TtydUser != "u" {
		t.Errorf("TtydUser: want u, got %q", b.TtydUser)
	}
	if b.TtydPass != "p" {
		t.Errorf("TtydPass: want p, got %q", b.TtydPass)
	}
}

func TestBuildBundle_V2Format(t *testing.T) {
	b := buildBundle("http://100.64.0.1:7681/ws", "admin", "secret")
	data, err := json.Marshal(b)
	if err != nil {
		t.Fatalf("json.Marshal failed: %v", err)
	}

	var m map[string]interface{}
	if err := json.Unmarshal(data, &m); err != nil {
		t.Fatalf("json.Unmarshal failed: %v", err)
	}

	wantKeys := []string{"v", "protocol", "endpoint", "ttyd_user", "ttyd_pass"}
	if len(m) != len(wantKeys) {
		t.Fatalf("want %d keys, got %d: %v", len(wantKeys), len(m), m)
	}
	for _, k := range wantKeys {
		if _, ok := m[k]; !ok {
			t.Errorf("missing key %q in JSON", k)
		}
	}
}

func TestBuildBundle_Protocol(t *testing.T) {
	b := buildBundle("http://100.64.0.1:7681/ws", "u", "p")
	if b.Protocol != "ttyd-tty/v1" {
		t.Errorf("Protocol: want ttyd-tty/v1, got %q", b.Protocol)
	}
}
