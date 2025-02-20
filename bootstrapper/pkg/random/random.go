package random

import (
	"crypto/rand"
	"encoding/base64"
	"log"
)

func Base64String(size int) string {
	bytes := make([]byte, size)
	_, err := rand.Read(bytes)
	if err != nil {
		log.Fatalf("Failed to generate random base64 string: %v", err)
	}

	return base64.URLEncoding.EncodeToString(bytes)
}
