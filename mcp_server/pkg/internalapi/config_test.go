package internalapi

import "testing"

func TestLoadConfigBaseURLDefault(t *testing.T) {
	t.Setenv(envBaseURL, "")
	t.Setenv(envDialTimeout, "5s")
	t.Setenv(envCallTimeout, "15s")

	cfg, err := LoadConfig()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if cfg.BaseURL != defaultBaseURL {
		t.Fatalf("expected base URL %q, got %q", defaultBaseURL, cfg.BaseURL)
	}
}

func TestLoadConfigBaseURLOverride(t *testing.T) {
	t.Setenv(envBaseURL, "  example.com ")
	t.Setenv(envDialTimeout, "5s")
	t.Setenv(envCallTimeout, "15s")

	cfg, err := LoadConfig()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if cfg.BaseURL != "example.com" {
		t.Fatalf("expected base URL %q, got %q", "example.com", cfg.BaseURL)
	}
}
