package secret

import (
	"os"
	"path/filepath"
	"testing"
)

func TestStoreLoad_FileRoundtrip_And0600(t *testing.T) {
	p := filepath.Join(t.TempDir(), "sub", "credential") // 含未建立的子目錄
	cfg := Config{Backend: "file", FilePath: p}

	if err := Store(cfg, "abc123"); err != nil {
		t.Fatalf("Store: %v", err)
	}
	got, err := Load(cfg)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if got != "abc123" {
		t.Fatalf("want abc123, got %q", got)
	}
	info, err := os.Stat(p)
	if err != nil {
		t.Fatal(err)
	}
	if perm := info.Mode().Perm(); perm != 0o600 {
		t.Fatalf("want 0600, got %#o", perm)
	}
}

func TestLoadFile_RejectsLoosePerms(t *testing.T) {
	p := filepath.Join(t.TempDir(), "credential")
	if err := os.WriteFile(p, []byte("secret"), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := Load(Config{Backend: "file", FilePath: p}); err == nil {
		t.Fatal("0644 權限過寬,Load 應拒絕")
	}
}

func TestLoadFile_TrimsWhitespace(t *testing.T) {
	p := filepath.Join(t.TempDir(), "credential")
	if err := os.WriteFile(p, []byte("  spaced\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	got, err := Load(Config{Backend: "file", FilePath: p})
	if err != nil {
		t.Fatal(err)
	}
	if got != "spaced" {
		t.Fatalf("want trimmed, got %q", got)
	}
}

func TestLoadEnv(t *testing.T) {
	t.Setenv("APP_TUNNEL_TEST_TOK", "  envtok  ")
	got, err := Load(Config{Backend: "env", EnvVar: "APP_TUNNEL_TEST_TOK"})
	if err != nil {
		t.Fatal(err)
	}
	if got != "envtok" {
		t.Fatalf("want trimmed envtok, got %q", got)
	}
}

func TestStoreEnv_Unsupported(t *testing.T) {
	if err := Store(Config{Backend: "env", EnvVar: "X"}, "v"); err == nil {
		t.Fatal("env 後端唯讀,Store 應報錯")
	}
}

func TestUnknownBackend(t *testing.T) {
	if _, err := Load(Config{Backend: "nope"}); err == nil {
		t.Fatal("未知後端應報錯")
	}
	if err := Store(Config{Backend: "nope"}, "v"); err == nil {
		t.Fatal("未知後端 Store 應報錯")
	}
}
