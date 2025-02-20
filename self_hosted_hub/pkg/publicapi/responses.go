package publicapi

import (
	"encoding/json"
	"net/http"
)

func respondWithJSON(w http.ResponseWriter, code int, payload interface{}) error {
	response, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)

	_, err = w.Write(response)
	return err
}

func respondWithString(w http.ResponseWriter, code int, payload string) error {
	w.WriteHeader(code)
	_, err := w.Write([]byte(payload))
	return err
}

func respondWith200(w http.ResponseWriter) {
	respond(w, http.StatusOK)
}

func respondWith404(w http.ResponseWriter) {
	respond(w, http.StatusNotFound)
}

func respondWith401(w http.ResponseWriter) {
	respond(w, http.StatusUnauthorized)
}

func respondWith422(w http.ResponseWriter) {
	respond(w, http.StatusUnprocessableEntity)
}

func respondWith500(w http.ResponseWriter) {
	respond(w, http.StatusInternalServerError)
}

func respond(w http.ResponseWriter, status int) {
	http.Error(w, http.StatusText(status), status)
}
