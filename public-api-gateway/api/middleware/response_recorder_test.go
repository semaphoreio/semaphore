package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestResponseRecorder(t *testing.T) {
	t.Run("Should record status code", func(t *testing.T) {
		w := httptest.NewRecorder()

		rr := NewResponseRecorder(w)

		rr.WriteHeader(http.StatusCreated)

		if rr.Status != http.StatusCreated {
			t.Errorf("Expected status code %d, got %d", http.StatusCreated, rr.Status)
		}

		if w.Code != http.StatusCreated {
			t.Errorf("Expected underlying writer status code %d, got %d", http.StatusCreated, w.Code)
		}
	})

	t.Run("Should record response body", func(t *testing.T) {
		w := httptest.NewRecorder()

		rr := NewResponseRecorder(w)

		testData := []byte("test response body")
		n, err := rr.Write(testData)

		if err != nil {
			t.Errorf("Expected no error, got %v", err)
		}
		if n != len(testData) {
			t.Errorf("Expected %d bytes written, got %d", len(testData), n)
		}

		if w.Body.String() != "test response body" {
			t.Errorf("Expected underlying writer body 'test response body', got '%s'", w.Body.String())
		}
	})

	t.Run("Should default to 200 OK status", func(t *testing.T) {
		w := httptest.NewRecorder()

		rr := NewResponseRecorder(w)

		if rr.Status != http.StatusOK {
			t.Errorf("Expected default status code %d, got %d", http.StatusOK, rr.Status)
		}
	})

	t.Run("Should handle multiple writes", func(t *testing.T) {
		w := httptest.NewRecorder()

		rr := NewResponseRecorder(w)

		rr.Write([]byte("first "))
		rr.Write([]byte("second "))
		rr.Write([]byte("third"))

		if w.Body.String() != "first second third" {
			t.Errorf("Expected underlying writer body 'first second third', got '%s'", w.Body.String())
		}
	})
}
