package internalapi

import (
	"context"
	"testing"

	pb "github.com/semaphoreio/semaphore/loghub2/pkg/protos/loghub2"
	assert "github.com/stretchr/testify/assert"
)

func Test__GeneratesTokenToPull(t *testing.T) {
	service := NewLoghub2Service("my-private-key")
	response, err := service.GenerateToken(context.Background(), &pb.GenerateTokenRequest{
		JobId:    "job1",
		Type:     pb.TokenType_PULL,
		Duration: 60,
	})

	assert.Nil(t, err)
	if assert.NotEmpty(t, response) {
		assert.Equal(t, response.GetType(), pb.TokenType_PULL)
		assert.Equal(t, response.GetType().String(), "PULL")
		assert.NotEmpty(t, response.GetToken())
	}
}

func Test__GeneratesTokenToPush(t *testing.T) {
	service := NewLoghub2Service("my-private-key")
	response, err := service.GenerateToken(context.Background(), &pb.GenerateTokenRequest{
		JobId:    "job1",
		Type:     pb.TokenType_PUSH,
		Duration: 60,
	})

	assert.Nil(t, err)
	if assert.NotEmpty(t, response) {
		assert.Equal(t, response.GetType(), pb.TokenType_PUSH)
		assert.Equal(t, response.GetType().String(), "PUSH")
		assert.NotEmpty(t, response.GetToken())
	}
}

func Test__GeneratesTokenToPullAsDefault(t *testing.T) {
	service := NewLoghub2Service("my-private-key")
	response, err := service.GenerateToken(context.Background(), &pb.GenerateTokenRequest{
		JobId:    "job1",
		Duration: 60,
	})

	assert.Nil(t, err)
	if assert.NotEmpty(t, response) {
		assert.Equal(t, response.GetType(), pb.TokenType_PULL)
		assert.Equal(t, response.GetType().String(), "PULL")
		assert.NotEmpty(t, response.GetToken())
	}
}
