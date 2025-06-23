package middleware

import (
	"net/http"
)

// ResponseRecorder is an http.ResponseWriter that records its status code
type ResponseRecorder struct {
	http.ResponseWriter
	Status int
}

func NewResponseRecorder(w http.ResponseWriter) *ResponseRecorder {
	return &ResponseRecorder{
		ResponseWriter: w,
		Status:         http.StatusOK,
	}
}

// WriteHeader records the status code
func (r *ResponseRecorder) WriteHeader(status int) {
	r.Status = status
	r.ResponseWriter.WriteHeader(status)
}

// Write forwards the body to the underlying ResponseWriter
func (r *ResponseRecorder) Write(b []byte) (int, error) {
	return r.ResponseWriter.Write(b)
}
