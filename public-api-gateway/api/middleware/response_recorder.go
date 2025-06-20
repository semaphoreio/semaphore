package middleware

import (
	"net/http"
	"strings"
)

// ResponseRecorder is an http.ResponseWriter that records its status code and body
type ResponseRecorder struct {
	http.ResponseWriter
	Status int
	Body   *strings.Builder
}

func NewResponseRecorder(w http.ResponseWriter) *ResponseRecorder {
	return &ResponseRecorder{
		ResponseWriter: w,
		Status:         http.StatusOK,
		Body:           &strings.Builder{},
	}
}

// WriteHeader records the status code
func (r *ResponseRecorder) WriteHeader(status int) {
	r.Status = status
	r.ResponseWriter.WriteHeader(status)
}

// Write records the body and forwards it to the underlying ResponseWriter
func (r *ResponseRecorder) Write(b []byte) (int, error) {
	r.Body.Write(b)
	return r.ResponseWriter.Write(b)
}
