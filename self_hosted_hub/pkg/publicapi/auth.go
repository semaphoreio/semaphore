package publicapi

import (
	"context"
	"net/http"
	"strings"

	securetoken "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/securetoken"
)

type contextKey string

var orgIDKey contextKey = "org-id"
var tokenHashKey contextKey = "token-hash"

func authMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		orgID := r.Header.Get("x-semaphore-org-id")
		if orgID == "" {
			respondWith404(w)
			return
		}

		reqToken := r.Header.Get("Authorization")
		if reqToken == "" {
			respondWith401(w)
			return
		}

		splitToken := strings.Split(reqToken, "Token ")
		if len(splitToken) != 2 {
			respondWith401(w)
			return
		}

		token := splitToken[1]
		tokenHash := securetoken.Hash(token)

		ctx := context.WithValue(r.Context(), orgIDKey, orgID)
		ctx = context.WithValue(ctx, tokenHashKey, tokenHash)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}
