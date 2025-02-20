package crypto

import (
	"encoding/base64"
	"fmt"
	"os"
)

type Encryptor interface {
	Encrypt(data []byte, associatedData []byte) ([]byte, error)
	Decrypt(data []byte, associatedData []byte) ([]byte, error)
}

func NewEncryptor(encryptorType string) (Encryptor, error) {
	switch encryptorType {
	case "no-op":
		return NewNoOpEncryptor()

	default:
		key := os.Getenv("ENCRYPTOR_AES_KEY")
		if key == "" {
			return nil, fmt.Errorf("ENCRYPTOR_AES_KEY is not set")
		}

		k, err := base64.URLEncoding.DecodeString(key)
		if err != nil {
			return nil, err
		}

		return NewAESGCMEncryptor(k)
	}
}
