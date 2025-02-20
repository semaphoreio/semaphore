package jwt

import (
	"fmt"
	"time"

	jwt "github.com/golang-jwt/jwt/v5"
)

type Claims struct {
	ArtifactID string
	Job        string
	Workflow   string
	Project    string
}

func GenerateToken(secret string, claims Claims, duration time.Duration) (string, error) {
	now := time.Now()
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"iat":      now.Unix(),
		"nbf":      now.Unix(),
		"exp":      now.Add(duration).Unix(),
		"sub":      claims.ArtifactID,
		"job":      claims.Job,
		"workflow": claims.Workflow,
		"project":  claims.Project,
	})

	tokenString, err := token.SignedString([]byte(secret))
	if err != nil {
		return "", err
	}

	return tokenString, nil
}

func ValidateToken(tokenString, secret string, validate func(jwt.MapClaims) error) (*Claims, error) {
	keyFn := func(token *jwt.Token) (interface{}, error) {
		return []byte(secret), nil
	}

	token, err := jwt.Parse(
		tokenString,
		keyFn,
		jwt.WithExpirationRequired(),
		jwt.WithValidMethods([]string{jwt.SigningMethodHS256.Name}),
		jwt.WithIssuedAt(),
	)

	if err != nil {
		return nil, err
	}

	if claims, ok := token.Claims.(jwt.MapClaims); ok && token.Valid {
		err := validate(claims)
		if err != nil {
			return nil, err
		}

		return &Claims{
			ArtifactID: claims["sub"].(string),
			Job:        claims["job"].(string),
			Workflow:   claims["workflow"].(string),
			Project:    claims["project"].(string),
		}, nil
	}

	return nil, fmt.Errorf("invalid token")
}
