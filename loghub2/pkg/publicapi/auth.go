package publicapi

import (
	"context"
	"net/http"
	"strings"
)

type contextKey string

var tokenContextKey contextKey = "jwt-token"

func authMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		orgID := r.Header.Get("x-semaphore-org-id")
		if orgID == "" {
			respondWith404(w)
			return
		}

		// Check if a JWT token is present as a query parameter
		token := r.URL.Query().Get("jwt")
		if token != "" {
			next.ServeHTTP(w, r.WithContext(
				context.WithValue(r.Context(), tokenContextKey, token),
			))

			return
		}

		// If not present as a query parameter,
		// check if one is not present as an HTTP header
		token = authFromHeader(r)
		if token == "" {
			respondWith401(w)
			return
		}

		next.ServeHTTP(w, r.WithContext(
			context.WithValue(r.Context(), tokenContextKey, token),
		))
	})
}

func authFromHeader(r *http.Request) string {
	reqToken := r.Header.Get("Authorization")
	if reqToken == "" {
		return ""
	}

	splitToken := strings.Split(reqToken, "Bearer ")
	if len(splitToken) != 2 {
		return ""
	}

	return splitToken[1]
}
