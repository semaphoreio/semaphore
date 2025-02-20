package securetoken

import (
	"testing"

	require "github.com/stretchr/testify/assert"
)

func Test(t *testing.T) {
	token, err := Create()
	require.Nil(t, err)

	require.Equal(t, token.Hash, Hash(token.Token))
}
