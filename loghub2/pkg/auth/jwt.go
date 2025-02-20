package auth

import (
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v4"
)

func GenerateToken(privateKey, subject, action string, duration time.Duration) (string, error) {
	now := time.Now()
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"iat":    now.Unix(),
		"nbf":    now.Unix(),
		"exp":    now.Add(duration).Unix(),
		"sub":    subject,
		"action": action,
	})

	tokenString, err := token.SignedString([]byte(privateKey))
	if err != nil {
		return "", err
	}

	return tokenString, nil
}

func ValidateToken(tokenString, privateKey, subject, action string) error {
	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}

		return []byte(privateKey), nil
	})

	if err != nil {
		return err
	}

	if claims, ok := token.Claims.(jwt.MapClaims); ok && token.Valid {
		epochSeconds := time.Now().Unix()
		if !claims.VerifyExpiresAt(epochSeconds, true) {
			return errors.New("missing exp")
		}

		if !claims.VerifyNotBefore(epochSeconds, true) {
			return errors.New("missing nbf")
		}

		if claims["sub"] != subject {
			return errors.New("subject is invalid")
		}

		if claims["action"] != action {
			return errors.New("action is invalid")
		}

		return nil
	}

	return errors.New("invalid token")
}
