package crypto

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func Test__NoOpEncryptorDoesNotEncryptAnything(t *testing.T) {
	encryptor, err := NewNoOpEncryptor()
	require.NoError(t, err)

	data := "testing encryption"
	assocData := "aaaa"
	cypher, err := encryptor.Encrypt([]byte(data), []byte(assocData))
	require.NoError(t, err)
	require.Equal(t, data, string(cypher))
}
