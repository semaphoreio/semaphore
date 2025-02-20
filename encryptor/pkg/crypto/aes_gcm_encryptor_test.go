package crypto

import (
	"crypto/rand"
	"testing"

	"github.com/stretchr/testify/require"
)

func Test__AESGCMEncryptor(t *testing.T) {
	t.Run("no key fails encryptor creation", func(t *testing.T) {
		encryptor, err := NewAESGCMEncryptor(nil)
		require.Error(t, err)
		require.Nil(t, encryptor)
	})

	t.Run("encrypts and decrypts properly", func(t *testing.T) {
		key := make([]byte, 32)
		_, _ = rand.Read(key)
		encryptor, err := NewAESGCMEncryptor(key)
		require.NoError(t, err)

		data := []byte("testing encryption")
		assocData := []byte("aaaa")

		// encryption works
		cyphertext, err := encryptor.Encrypt(data, assocData)
		require.NoError(t, err)
		require.NotEmpty(t, cyphertext)

		// decryption works
		plaintext, err := encryptor.Decrypt(cyphertext, assocData)
		require.NoError(t, err)
		require.Equal(t, data, plaintext)
	})

	t.Run("decryption fails with wrong key", func(t *testing.T) {
		data := []byte("testing encryption")
		assocData := []byte("aaaa")

		// create two different keys
		key1 := make([]byte, 32)
		_, _ = rand.Read(key1)
		encryptor1, _ := NewAESGCMEncryptor(key1)

		key2 := make([]byte, 32)
		_, _ = rand.Read(key2)
		encryptor2, _ := NewAESGCMEncryptor(key2)

		// encryption works, but decryption fails
		cyphertext, err := encryptor1.Encrypt(data, assocData)
		require.NoError(t, err)
		require.NotEmpty(t, cyphertext)
		plain, err := encryptor2.Decrypt(cyphertext, assocData)
		require.Error(t, err)
		require.Nil(t, plain)
	})

	t.Run("decryption fails with wrong associated data", func(t *testing.T) {
		key := make([]byte, 32)
		_, _ = rand.Read(key)
		encryptor, err := NewAESGCMEncryptor(key)
		require.NoError(t, err)

		data := []byte("testing encryption")
		assocData := []byte("aaaa")

		// encryption works
		cyphertext, err := encryptor.Encrypt(data, assocData)
		require.NoError(t, err)
		require.NotEmpty(t, cyphertext)

		// decryption fails
		plaintext, err := encryptor.Decrypt(cyphertext, []byte("bbbb"))
		require.Error(t, err)
		require.Nil(t, plaintext)
	})
}
