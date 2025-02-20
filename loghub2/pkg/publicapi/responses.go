package publicapi

import (
	"net/http"
)

type LogResponse struct {
	Next   *int64        `json:"next"`
	Events []interface{} `json:"events"`
}

func respondWith200(w http.ResponseWriter) {
	respond(w, http.StatusOK)
}

func respondWith401(w http.ResponseWriter) {
	respond(w, http.StatusUnauthorized)
}

func respondWith404(w http.ResponseWriter) {
	respond(w, http.StatusNotFound)
}

func respond(w http.ResponseWriter, status int) {
	http.Error(w, http.StatusText(status), status)
}
