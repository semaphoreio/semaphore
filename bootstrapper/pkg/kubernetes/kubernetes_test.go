package kubernetes

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	v1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes/fake"
)

func Test__UpsertSecret(t *testing.T) {
	namespace := "default"
	clientset := fake.NewSimpleClientset()
	client := NewClientWithClientset(clientset, namespace)
	secretName := "mysecret"

	t.Run("secret is created", func(t *testing.T) {
		assert.NoError(t, client.UpsertSecret(secretName, map[string]string{
			"a": "a",
			"b": "b",
		}))

		secret, err := clientset.CoreV1().
			Secrets(namespace).
			Get(context.Background(), secretName, v1.GetOptions{})

		assert.NoError(t, err)
		assert.Equal(t, secret.Name, secretName)
		assert.Empty(t, secret.Labels)
		assert.Equal(t, secret.StringData, map[string]string{
			"a": "a",
			"b": "b",
		})
	})

	t.Run("secret data is updated", func(t *testing.T) {
		assert.NoError(t, client.UpsertSecret(secretName, map[string]string{
			"b": "bb",
			"c": "c",
		}))

		secret, err := clientset.CoreV1().
			Secrets("default").
			Get(context.Background(), secretName, v1.GetOptions{})

		assert.NoError(t, err)
		assert.Equal(t, secret.Name, secretName)
		assert.Empty(t, secret.Labels)
		assert.Equal(t, secret.StringData, map[string]string{
			"a": "a",
			"b": "bb",
			"c": "c",
		})
	})

	t.Run("secret labels are updated", func(t *testing.T) {
		assert.NoError(t, client.UpsertSecretWithLabels(secretName, map[string]string{}, map[string]string{
			"label-a": "a",
		}))

		secret, err := clientset.CoreV1().
			Secrets("default").
			Get(context.Background(), secretName, v1.GetOptions{})

		assert.NoError(t, err)
		assert.Equal(t, secret.Name, secretName)
		assert.Equal(t, secret.Labels, map[string]string{
			"label-a": "a",
		})
		assert.Equal(t, secret.StringData, map[string]string{
			"a": "a",
			"b": "bb",
			"c": "c",
		})
	})
}
