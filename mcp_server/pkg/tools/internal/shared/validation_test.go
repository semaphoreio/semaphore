package shared

import (
	"strings"
	"testing"
)

func TestSanitizeCursorToken(t *testing.T) {
	t.Parallel()

	longCursor := strings.Repeat("a", 513)

	tests := []struct {
		name    string
		input   string
		want    string
		wantErr bool
	}{
		{name: "empty allowed", input: "", want: ""},
		{name: "basic token", input: "abc123", want: "abc123"},
		{name: "with punctuation", input: "next-page:/token+1=", want: "next-page:/token+1="},
		{name: "trims whitespace", input: "  token  ", want: "token"},
		{name: "contains space", input: "bad token", wantErr: true},
		{name: "contains control rune", input: "bad\n", wantErr: true},
		{name: "too long", input: longCursor, wantErr: true},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()

			got, err := SanitizeCursorToken(tt.input, "cursor")
			if tt.wantErr {
				if err == nil {
					t.Fatalf("expected error for input %q", tt.input)
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if got != tt.want {
				t.Fatalf("expected %q, got %q", tt.want, got)
			}
		})
	}
}

func TestSanitizeBranch(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name    string
		input   string
		want    string
		wantErr bool
	}{
		{name: "empty branch allowed", input: "", want: ""},
		{name: "simple branch", input: "main", want: "main"},
		{name: "slash branch", input: "feature/new-ui", want: "feature/new-ui"},
		{name: "trims whitespace", input: " release/v1 ", want: "release/v1"},
		{name: "double dots blocked", input: "bad..branch", wantErr: true},
		{name: "double slash blocked", input: "bad//branch", wantErr: true},
		{name: "at brace blocked", input: "feature@{bad}", wantErr: true},
		{name: "invalid char", input: "feature$bug", wantErr: true},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()

			got, err := SanitizeBranch(tt.input, "branch")
			if tt.wantErr {
				if err == nil {
					t.Fatalf("expected error for input %q", tt.input)
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if got != tt.want {
				t.Fatalf("expected %q, got %q", tt.want, got)
			}
		})
	}
}

func TestSanitizeRequesterFilter(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name    string
		input   string
		want    string
		wantErr bool
	}{
		{name: "empty allowed", input: "", want: ""},
		{name: "lowercase ok", input: "deploy-bot", want: "deploy-bot"},
		{name: "upper gets normalized", input: "Deploy.Bot", want: "deploy.bot"},
		{name: "invalid char blocked", input: "user!name", wantErr: true},
		{name: "too long", input: strings.Repeat("a", 80), wantErr: true},
		{name: "contains space", input: "user name", wantErr: true},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()

			got, err := SanitizeRequesterFilter(tt.input, "requester")
			if tt.wantErr {
				if err == nil {
					t.Fatalf("expected error for input %q", tt.input)
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if got != tt.want {
				t.Fatalf("expected %q, got %q", tt.want, got)
			}
		})
	}
}

func TestSanitizeSearchQuery(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name    string
		input   string
		want    string
		wantErr bool
	}{
		{name: "empty ok", input: "", want: ""},
		{name: "basic query", input: "status:failed branch main", want: "status:failed branch main"},
		{name: "trim spaces", input: "  failure reason  ", want: "failure reason"},
		{name: "quote rejected", input: `value"drop`, wantErr: true},
		{name: "backslash rejected", input: `value\drop`, wantErr: true},
		{name: "newline rejected", input: "foo\nbar", wantErr: true},
		{name: "too long", input: strings.Repeat("q", 300), wantErr: true},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()

			got, err := SanitizeSearchQuery(tt.input, "query")
			if tt.wantErr {
				if err == nil {
					t.Fatalf("expected error for input %q", tt.input)
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if got != tt.want {
				t.Fatalf("expected %q, got %q", tt.want, got)
			}
		})
	}
}

func TestSanitizeRepositoryURLFilter(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name    string
		input   string
		want    string
		wantErr bool
	}{
		{name: "empty allowed", input: "", want: ""},
		{name: "https url", input: "https://github.com/org/repo", want: "https://github.com/org/repo"},
		{name: "ssh url", input: "git@github.com:org/repo.git", want: "git@github.com:org/repo.git"},
		{name: "trims whitespace", input: "  github.com/org/repo.git  ", want: "github.com/org/repo.git"},
		{name: "invalid char", input: "github.com/org/repo|bad", wantErr: true},
		{name: "space rejected", input: "github.com/org bad", wantErr: true},
		{name: "too long", input: "https://" + strings.Repeat("a", 520), wantErr: true},
		{name: "control rune rejected", input: "github.com/org\nrepo", wantErr: true},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()

			got, err := SanitizeRepositoryURLFilter(tt.input, "repository_url")
			if tt.wantErr {
				if err == nil {
					t.Fatalf("expected error for input %q", tt.input)
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if got != tt.want {
				t.Fatalf("expected %q, got %q", tt.want, got)
			}
		})
	}
}
