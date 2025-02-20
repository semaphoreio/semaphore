package jwt

import (
	"crypto/rand"
	"crypto/rsa"
	"errors"
	"testing"
	"time"

	jwt "github.com/golang-jwt/jwt/v5"
	uuid "github.com/satori/go.uuid"
	assert "github.com/stretchr/testify/assert"
)

var (
	noOpValidateFn = func(mc jwt.MapClaims) error { return nil }
	testSecret     = "my-very-important-and-secret-private-key"
	testClaims     = Claims{
		ArtifactID: uuid.NewV4().String(),
		Job:        uuid.NewV4().String(),
		Workflow:   uuid.NewV4().String(),
		Project:    uuid.NewV4().String(),
	}
)

func Test__GeneratedTokenIsValid(t *testing.T) {
	token, err := GenerateToken(testSecret, testClaims, time.Minute)
	assert.Nil(t, err)

	claims, err := ValidateToken(token, testSecret, noOpValidateFn)
	assert.Nil(t, err)
	assert.Equal(t, claims.ArtifactID, testClaims.ArtifactID)
	assert.Equal(t, claims.Workflow, testClaims.Workflow)
	assert.Equal(t, claims.Project, testClaims.Project)
	assert.Equal(t, claims.Job, testClaims.Job)
}

func Test__BadKeyFailsValidation(t *testing.T) {
	token, err := GenerateToken(testSecret, testClaims, time.Minute)
	assert.Nil(t, err)

	_, err = ValidateToken(token, "bad-key", noOpValidateFn)
	assert.ErrorIs(t, err, jwt.ErrTokenSignatureInvalid)
}

func Test__BadSigningMethodFailsValidation(t *testing.T) {
	key, err := rsa.GenerateKey(rand.Reader, 4096)
	if err != nil {
		panic(err)
	}

	token := jwt.NewWithClaims(jwt.SigningMethodRS256, jwt.MapClaims{
		"iat":      time.Now().Unix(),
		"nbf":      time.Now().Unix(),
		"exp":      time.Now().Add(1 * time.Hour).Unix(),
		"sub":      testClaims.ArtifactID,
		"job":      testClaims.Job,
		"workflow": testClaims.Workflow,
		"project":  testClaims.Project,
	})

	tokenString, err := token.SignedString(key)
	assert.NoError(t, err)
	assert.NotEmpty(t, tokenString)

	_, err = ValidateToken(tokenString, testSecret, noOpValidateFn)
	assert.ErrorIs(t, err, jwt.ErrTokenSignatureInvalid)
	assert.ErrorContains(t, err, "signing method RS256 is invalid")
}

func Test__MissingExpiredAtFailsValidation(t *testing.T) {
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"iat":      time.Now().Unix(),
		"nbf":      time.Now().Unix(),
		"sub":      testClaims.ArtifactID,
		"job":      testClaims.Job,
		"workflow": testClaims.Workflow,
		"project":  testClaims.Project,
	})

	tokenString, _ := token.SignedString([]byte(testSecret))
	_, err := ValidateToken(tokenString, testSecret, noOpValidateFn)
	assert.ErrorIs(t, err, jwt.ErrTokenRequiredClaimMissing)
}

func Test__ExpiredTokenFailsValidation(t *testing.T) {
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"iat":      time.Now().Add(-2 * time.Hour).Unix(),
		"nbf":      time.Now().Add(-2 * time.Hour).Unix(),
		"exp":      time.Now().Add(-time.Hour).Unix(),
		"sub":      testClaims.ArtifactID,
		"job":      testClaims.Job,
		"workflow": testClaims.Workflow,
		"project":  testClaims.Project,
	})

	tokenString, _ := token.SignedString([]byte(testSecret))
	_, err := ValidateToken(tokenString, testSecret, noOpValidateFn)
	assert.ErrorIs(t, err, jwt.ErrTokenExpired)
}

func Test__BadIssuedAtFailsValidation(t *testing.T) {
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"iat":      time.Now().Add(2 * time.Hour).Unix(),
		"exp":      time.Now().Add(4 * time.Hour).Unix(),
		"sub":      testClaims.ArtifactID,
		"job":      testClaims.Job,
		"workflow": testClaims.Workflow,
		"project":  testClaims.Project,
	})

	tokenString, _ := token.SignedString([]byte(testSecret))
	_, err := ValidateToken(tokenString, testSecret, noOpValidateFn)
	assert.ErrorIs(t, err, jwt.ErrTokenUsedBeforeIssued)
}

func Test__ValidateFunctionFails(t *testing.T) {
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"iat":      time.Now().Unix(),
		"nbf":      time.Now().Unix(),
		"exp":      time.Now().Add(time.Hour).Unix(),
		"sub":      testClaims.ArtifactID,
		"job":      testClaims.Job,
		"workflow": "oops",
		"project":  testClaims.Project,
	})

	tokenString, _ := token.SignedString([]byte(testSecret))
	_, err := ValidateToken(tokenString, testSecret, func(claims jwt.MapClaims) error {
		if claims["workflow"] != testClaims.Workflow {
			return errors.New("workflow is invalid")
		}

		return nil
	})

	assert.ErrorContains(t, err, "workflow is invalid")
}
