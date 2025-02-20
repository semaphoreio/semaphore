package auth

import (
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v4"
	assert "github.com/stretchr/testify/assert"
)

const (
	TestPrivateKey = "my-very-important-and-secret-private-key"
	TestSubject    = "subject1"
	TestAction     = "PUSH"
)

func Test__GeneratedTokenIsValid(t *testing.T) {
	token, err := GenerateToken(TestPrivateKey, TestSubject, TestAction, time.Minute)
	assert.Nil(t, err)

	err = ValidateToken(token, TestPrivateKey, TestSubject, TestAction)
	assert.Nil(t, err)
}

func Test__BadKeyFailsValidation(t *testing.T) {
	token, err := GenerateToken(TestPrivateKey, TestSubject, TestAction, time.Minute)
	assert.Nil(t, err)

	err = ValidateToken(token, "bad-key", TestSubject, TestAction)
	validationErr, _ := err.(*jwt.ValidationError)
	if assert.Error(t, validationErr) {
		assert.Equal(t, "signature is invalid", validationErr.Error())
	}
}

func Test__BadSubjectFailsValidation(t *testing.T) {
	token, err := GenerateToken(TestPrivateKey, TestSubject, TestAction, time.Minute)
	assert.Nil(t, err)

	err = ValidateToken(token, TestPrivateKey, "bad-subject", TestAction)
	if assert.Error(t, err) {
		assert.Equal(t, "subject is invalid", err.Error())
	}
}

func Test__MissingSubjectFailsValidation(t *testing.T) {
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"iat":    time.Now().Unix(),
		"nbf":    time.Now().Unix(),
		"exp":    time.Now().Add(time.Hour).Unix(),
		"action": TestAction,
	})

	tokenString, _ := token.SignedString([]byte(TestPrivateKey))
	err := ValidateToken(tokenString, TestPrivateKey, TestSubject, TestAction)
	if assert.Error(t, err) {
		assert.Equal(t, "subject is invalid", err.Error())
	}
}

func Test__MissingExpiredAtFailsValidation(t *testing.T) {
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"iat":    time.Now().Unix(),
		"nbf":    time.Now().Unix(),
		"sub":    TestSubject,
		"action": TestAction,
	})

	tokenString, _ := token.SignedString([]byte(TestPrivateKey))
	err := ValidateToken(tokenString, TestPrivateKey, TestSubject, TestAction)
	if assert.Error(t, err) {
		assert.Equal(t, "missing exp", err.Error())
	}
}

func Test__ExpiredTokenFailsValidation(t *testing.T) {
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"iat":    time.Now().Add(-2 * time.Hour).Unix(),
		"nbf":    time.Now().Add(-2 * time.Hour).Unix(),
		"exp":    time.Now().Add(-time.Hour).Unix(),
		"action": TestAction,
	})

	tokenString, _ := token.SignedString([]byte(TestPrivateKey))

	err := ValidateToken(tokenString, TestPrivateKey, TestSubject, TestAction)
	validationErr, _ := err.(*jwt.ValidationError)
	if assert.Error(t, validationErr) {
		assert.Equal(t, "Token is expired", validationErr.Error())
	}
}

func Test__BadNotBeforeFailsValidation(t *testing.T) {
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"iat":    time.Now().Add(time.Hour).Unix(),
		"nbf":    time.Now().Add(time.Hour).Unix(),
		"exp":    time.Now().Add(2 * time.Hour).Unix(),
		"sub":    TestSubject,
		"action": TestAction,
	})

	tokenString, _ := token.SignedString([]byte(TestPrivateKey))

	err := ValidateToken(tokenString, TestPrivateKey, TestSubject, TestAction)
	validationErr, _ := err.(*jwt.ValidationError)
	if assert.Error(t, validationErr) {
		assert.Equal(t, "Token is not valid yet", validationErr.Error())
	}
}

func Test__MissingNotBeforeFailsValidation(t *testing.T) {
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"iat":    time.Now().Unix(),
		"exp":    time.Now().Add(time.Hour).Unix(),
		"sub":    TestSubject,
		"action": TestAction,
	})

	tokenString, _ := token.SignedString([]byte(TestPrivateKey))
	err := ValidateToken(tokenString, TestPrivateKey, TestSubject, TestAction)
	if assert.Error(t, err) {
		assert.Equal(t, "missing nbf", err.Error())
	}
}

func Test__BadActionFailsValidation(t *testing.T) {
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"iat":    time.Now().Unix(),
		"nbf":    time.Now().Unix(),
		"exp":    time.Now().Add(time.Hour).Unix(),
		"sub":    TestSubject,
		"action": TestAction,
	})

	tokenString, _ := token.SignedString([]byte(TestPrivateKey))

	err := ValidateToken(tokenString, TestPrivateKey, TestSubject, "bad-action")
	if assert.Error(t, err) {
		assert.Equal(t, "action is invalid", err.Error())
	}
}

func Test__MissingActionFailsValidation(t *testing.T) {
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"iat": time.Now().Unix(),
		"nbf": time.Now().Unix(),
		"exp": time.Now().Add(time.Hour).Unix(),
		"sub": TestSubject,
	})

	tokenString, _ := token.SignedString([]byte(TestPrivateKey))
	err := ValidateToken(tokenString, TestPrivateKey, TestSubject, TestAction)
	if assert.Error(t, err) {
		assert.Equal(t, "action is invalid", err.Error())
	}
}
