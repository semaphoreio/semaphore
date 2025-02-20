package api

import (
	"context"
	"testing"

	"github.com/semaphoreio/semaphore/encryptor/pkg/crypto"
	pb "github.com/semaphoreio/semaphore/encryptor/pkg/protos/encryptor"
	"github.com/stretchr/testify/require"
)

var encryptor, _ = crypto.NewNoOpEncryptor()
var testService = NewEncryptorService(encryptor)

func Test__Encrypt(t *testing.T) {
	message := "very sensitive information"

	// encryption works
	response, err := testService.Encrypt(context.TODO(), &pb.EncryptRequest{
		Raw:            []byte(message),
		AssociatedData: []byte{},
	})

	require.NoError(t, err)
	require.NotEmpty(t, response.Cypher)
	require.Equal(t, message, string(response.Cypher))
}
