package bench

import (
	"bytes"
	"log"
	"strings"
	"testing"
	"time"
)

func TestObserve_LogsSlowMeasurements(t *testing.T) {
	out := captureLog(t, 500*time.Millisecond, func() {
		Observe(time.Now().Add(-2*time.Second), "gitrekt.Search", "https://github.com/foo/bar")
	})

	for _, want := range []string{
		"(bench)",
		"metric=gitrekt.Search",
		"duration_ms=200",
		"target=https://github.com/foo/bar",
	} {
		if !strings.Contains(out, want) {
			t.Errorf("log %q does not contain %q", out, want)
		}
	}
}

func TestObserve_SkipsFastMeasurements(t *testing.T) {
	out := captureLog(t, time.Second, func() {
		Observe(time.Now(), "gitrekt.Search", "https://github.com/foo/bar")
	})

	if out != "" {
		t.Errorf("expected no log output, got %q", out)
	}
}

func TestObserve_ZeroThresholdLogsEverything(t *testing.T) {
	out := captureLog(t, 0, func() {
		Observe(time.Now(), "hub.Describe", "9c1a2b3d-0000-0000-0000-000000000000")
	})

	if !strings.Contains(out, "metric=hub.Describe") {
		t.Errorf("expected the measurement to be logged, got %q", out)
	}
}

func TestReadLogThreshold(t *testing.T) {
	for _, test := range []struct {
		raw  string
		want time.Duration
	}{
		{raw: "", want: defaultLogThreshold},
		{raw: "0", want: 0},
		{raw: "250", want: 250 * time.Millisecond},
		{raw: "-1", want: defaultLogThreshold},
		{raw: "soon", want: defaultLogThreshold},
	} {
		log.SetOutput(&bytes.Buffer{})
		got := readLogThreshold(test.raw)
		log.SetOutput(originalLogOutput)

		if got != test.want {
			t.Errorf("readLogThreshold(%q) = %v, want %v", test.raw, got, test.want)
		}
	}
}

//
// Internals
//

var originalLogOutput = log.Writer()

func captureLog(t *testing.T, threshold time.Duration, f func()) string {
	t.Helper()

	previousThreshold := logThreshold
	logThreshold = threshold

	out := &bytes.Buffer{}
	log.SetOutput(out)

	defer func() {
		logThreshold = previousThreshold
		log.SetOutput(originalLogOutput)
	}()

	f()

	return out.String()
}
