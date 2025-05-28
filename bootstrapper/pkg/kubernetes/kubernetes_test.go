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

func Test__CreateSecretIfNotExists(t *testing.T) {
	namespace := "default"
	clientset := fake.NewSimpleClientset()
	client := NewClientWithClientset(clientset, namespace)

	t.Run("new secret is created", func(t *testing.T) {
		secretName := "newsecret"

		assert.NoError(t, client.CreateSecretIfNotExists(secretName, map[string]string{
			"key1": "value1",
			"key2": "value2",
		}))

		secret, err := clientset.CoreV1().
			Secrets(namespace).
			Get(context.Background(), secretName, v1.GetOptions{})

		assert.NoError(t, err)
		assert.Equal(t, secret.Name, secretName)
		assert.Empty(t, secret.Labels)
		assert.Equal(t, secret.StringData, map[string]string{
			"key1": "value1",
			"key2": "value2",
		})
	})

	t.Run("existing secret is not modified", func(t *testing.T) {
		secretName := "existingsecret"

		// Create the secret first
		assert.NoError(t, client.CreateSecretIfNotExists(secretName, map[string]string{
			"original": "data",
		}))

		// Try to create it again with different data
		assert.NoError(t, client.CreateSecretIfNotExists(secretName, map[string]string{
			"new": "data",
		}))

		// Secret should still have the original data
		secret, err := clientset.CoreV1().
			Secrets(namespace).
			Get(context.Background(), secretName, v1.GetOptions{})

		assert.NoError(t, err)
		assert.Equal(t, secret.Name, secretName)
		assert.Equal(t, secret.StringData, map[string]string{
			"original": "data",
		})
	})
}

func Test__CreateSecretWithLabelsIfNotExists(t *testing.T) {
	namespace := "default"
	clientset := fake.NewSimpleClientset()
	client := NewClientWithClientset(clientset, namespace)

	t.Run("new secret is created with labels", func(t *testing.T) {
		secretName := "labeledsecret"

		assert.NoError(t, client.CreateSecretWithLabelsIfNotExists(secretName, map[string]string{
			"app": "test",
		}, map[string]string{
			"label1": "value1",
			"label2": "value2",
		}))

		secret, err := clientset.CoreV1().
			Secrets(namespace).
			Get(context.Background(), secretName, v1.GetOptions{})

		assert.NoError(t, err)
		assert.Equal(t, secret.Name, secretName)
		assert.Equal(t, secret.Labels, map[string]string{
			"label1": "value1",
			"label2": "value2",
		})
		assert.Equal(t, secret.StringData, map[string]string{
			"app": "test",
		})
	})

	t.Run("existing labeled secret is not modified", func(t *testing.T) {
		secretName := "existinglabeledsecret"

		// Create the secret first with labels
		assert.NoError(t, client.CreateSecretWithLabelsIfNotExists(secretName, map[string]string{
			"original": "data",
		}, map[string]string{
			"original": "label",
		}))

		// Try to create it again with different data and labels
		assert.NoError(t, client.CreateSecretWithLabelsIfNotExists(secretName, map[string]string{
			"new": "data",
		}, map[string]string{
			"new": "label",
		}))

		// Secret should still have the original data and labels
		secret, err := clientset.CoreV1().
			Secrets(namespace).
			Get(context.Background(), secretName, v1.GetOptions{})

		assert.NoError(t, err)
		assert.Equal(t, secret.Name, secretName)
		assert.Equal(t, secret.Labels, map[string]string{
			"original": "label",
		})
		assert.Equal(t, secret.StringData, map[string]string{
			"original": "data",
		})
	})
}
