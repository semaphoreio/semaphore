package securetoken

import (
	"crypto/rand"
	"crypto/sha256"
	"fmt"
)

type Token struct {
	Token string
	Hash  string
}

const TokenLength = 40

func Create() (*Token, error) {
	token := make([]byte, TokenLength)

	_, err := rand.Read(token)
	if err != nil {
		return nil, err
	}

	tokenString := fmt.Sprintf("%x", token)

	return &Token{
		Token: tokenString,
		Hash:  Hash(tokenString),
	}, nil
}

func Hash(token string) string {
	hash := sha256.Sum256([]byte(token))
	hashString := fmt.Sprintf("%x", hash)

	return hashString
}
