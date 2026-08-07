package storage

import (
	"mime"
	"net/url"
	"strings"
	"testing"
)

// Regression test for the ".txt returns HTTP 400" bug. AppendContentType must
// percent-encode the mime value it appends to the signed URL. In production
// OIB_OTHER_MIMES maps ".txt" -> "text/plain; charset=utf-8", whose space made
// the URL malformed: browsers re-encoded it and worked, but programmatic
// clients (sem-ai / curl) sent the raw space and GCS rejected it with HTTP 400.
func TestAppendContentType(t *testing.T) {
	const base = "https://storage.googleapis.com/bucket/artifacts/workflows/abc/f.txt?X-Goog-Signature=deadbeef"

	// assertWellFormed checks the returned URL has no raw space, parses cleanly,
	// and round-trips the expected response-content-* overrides.
	assertWellFormed := func(t *testing.T, got, wantContentType string) {
		t.Helper()

		query := got[strings.Index(got, "?")+1:]
		if strings.Contains(query, " ") {
			t.Fatalf("signed URL query contains a raw space (malformed): %q", got)
		}

		u, err := url.Parse(got)
		if err != nil {
			t.Fatalf("url.Parse(%q) failed: %v", got, err)
		}
		if ct := u.Query().Get("response-content-type"); ct != wantContentType {
			t.Fatalf("response-content-type = %q, want %q", ct, wantContentType)
		}
		if disp := u.Query().Get("response-content-disposition"); disp != "inline" {
			t.Fatalf("response-content-disposition = %q, want %q", disp, "inline")
		}
	}

	t.Run("extra mime with charset (.txt) is encoded", func(t *testing.T) {
		extra := map[string]string{".txt": "text/plain; charset=utf-8"}
		got := AppendContentType(map[string]bool{}, extra, base, "dir/f.txt")
		assertWellFormed(t, got, "text/plain; charset=utf-8")
		if !strings.Contains(got, "%20") {
			t.Fatalf("expected the space to be encoded as %%20, got %q", got)
		}
	})

	t.Run("open-in-browser mime (.html) is encoded", func(t *testing.T) {
		// Derive the expected mime from the runtime table so the test does not
		// depend on the container's /etc/mime.types (typically
		// "text/html; charset=utf-8").
		want := mime.TypeByExtension(".html")
		if want == "" {
			t.Skip("no mime mapping for .html in this environment")
		}
		mimes := map[string]bool{want: true}
		got := AppendContentType(mimes, map[string]string{}, base, "index.html")
		assertWellFormed(t, got, want)
	})

	t.Run("extra mime without special chars (.md)", func(t *testing.T) {
		extra := map[string]string{".md": "text/plain"}
		got := AppendContentType(map[string]bool{}, extra, base, "README.md")
		assertWellFormed(t, got, "text/plain")
	})

	t.Run("no mime match returns URL unchanged", func(t *testing.T) {
		got := AppendContentType(map[string]bool{}, map[string]string{}, base, "data.bin")
		if got != base {
			t.Fatalf("expected unchanged URL, got %q", got)
		}
	})
}
