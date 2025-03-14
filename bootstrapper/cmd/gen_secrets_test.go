package cmd

import (
	"context"
	"fmt"
	"os"
	"strings"
	"testing"

	"github.com/semaphoreio/semaphore/bootstrapper/pkg/kubernetes"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/utils"
	"github.com/stretchr/testify/assert"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes/fake"
)

// setTestEnv sets up the environment variables needed for tests
func setTestEnv(edition string) func() {
	envVars := map[string]string{
		"JWT_SECRET_NAME":            "jwt-secret",
		"AUTHENTICATION_SECRET_NAME": "auth-secret",
		"ENCRYPTION_SECRET_NAME":     "encryption-secret",
		"KUBERNETES_NAMESPACE":       "test",
		"OPENID_SECRET_NAME":         "openid-secret",
		"VAULT_SECRET_NAME":          "vault-secret",
	}

	if edition != "" {
		envVars["SEMAPHORE_EDITION"] = edition
	}

	// Set all environment variables
	for key, value := range envVars {
		os.Setenv(key, value)
	}

	// Return cleanup function
	return func() {
		for key := range envVars {
			os.Unsetenv(key)
		}
	}
}

// MockKubernetesClient implements the minimal interface needed for testing
type MockKubernetesClient struct {
	*kubernetes.KubernetesClient
	Clientset *fake.Clientset
}

func NewMockKubernetesClient() *MockKubernetesClient {
	fakeClientset := fake.NewSimpleClientset()
	return &MockKubernetesClient{
		KubernetesClient: kubernetes.NewClientWithClientset(fakeClientset, "test"),
		Clientset:        fakeClientset,
	}
}

func TestGenerateRSAKey(t *testing.T) {
	// Test generateRSAKeyPair
	privateKey, publicKey, err := generateRSAKeyPair()
	assert.NoError(t, err)
	assert.NotNil(t, privateKey)
	assert.NotNil(t, publicKey)

	// Verify private key format
	assert.True(t, strings.Contains(string(privateKey), "-----BEGIN RSA PRIVATE KEY-----"))
	assert.True(t, strings.Contains(string(privateKey), "-----END RSA PRIVATE KEY-----"))

	// Verify public key format
	assert.True(t, strings.Contains(string(publicKey), "-----BEGIN RSA PUBLIC KEY-----"))
	assert.True(t, strings.Contains(string(publicKey), "-----END RSA PUBLIC KEY-----"))

	// Test generateRSAKey (which should only return private key)
	privateKeyOnly, _, err := generateRSAKeyPair()
	assert.NoError(t, err)
	assert.NotNil(t, privateKeyOnly)
	assert.True(t, strings.Contains(string(privateKeyOnly), "-----BEGIN RSA PRIVATE KEY-----"))
	assert.True(t, strings.Contains(string(privateKeyOnly), "-----END RSA PRIVATE KEY-----"))
}

func TestGenerateOpenIDSecret(t *testing.T) {
	// Set required env vars
	cleanup := setTestEnv("ee")
	defer cleanup()

	mockClient := NewMockKubernetesClient()

	err := generateOpenIDSecret(mockClient.KubernetesClient)
	assert.NoError(t, err)

	// Verify the secret was created with correct format
	secret, err := mockClient.Clientset.CoreV1().Secrets("test").Get(context.Background(), "openid-secret", metav1.GetOptions{})
	assert.NoError(t, err)
	assert.NotNil(t, secret)
	// Verify secret type
	assert.Equal(t, corev1.SecretTypeOpaque, secret.Type)

	// Verify there's exactly one key pair with correct format
	foundPrivate := false

	// Helper function to check keys in either StringData or Data
	checkKeys := func(data map[string]string) {
		for k, v := range data {
			if strings.HasSuffix(k, ".pem") && strings.Contains(v, "-----BEGIN RSA PRIVATE KEY-----") {
				foundPrivate = true
			}
		}
	}

	// Check StringData first
	checkKeys(secret.StringData)

	// If not found in StringData, check Data
	if !foundPrivate {
		data := make(map[string]string)
		for k, v := range secret.Data {
			data[k] = string(v)
		}
		checkKeys(data)
	}

	assert.True(t, foundPrivate, "No valid RSA private key found in secret")
}

func TestGenerateVaultSecret(t *testing.T) {
	// Set required env vars
	cleanup := setTestEnv("ee")
	defer cleanup()

	mockClient := NewMockKubernetesClient()

	err := generateVaultSecret(mockClient.KubernetesClient)
	assert.NoError(t, err)

	// Verify the secret was created with correct format
	secret, err := mockClient.Clientset.CoreV1().Secrets("test").Get(context.Background(), utils.AssertEnv("VAULT_SECRET_NAME"), metav1.GetOptions{})
	assert.NoError(t, err)
	assert.NotNil(t, secret)
	// Verify secret type
	assert.Equal(t, corev1.SecretTypeOpaque, secret.Type)

	// Verify there's exactly one key pair with correct format
	foundPrivate := false
	foundPublic := false
	timestamp := ""

	// Helper function to check keys in either StringData or Data
	checkKeys := func(data map[string]string) {
		for k, v := range data {
			if strings.HasSuffix(k, ".prv.pem") && strings.Contains(v, "-----BEGIN RSA PRIVATE KEY-----") {
				foundPrivate = true
				// Extract timestamp from the key name
				timestamp = strings.TrimSuffix(k, ".prv.pem")
			}
			if strings.HasSuffix(k, ".pub.pem") && strings.Contains(v, "-----BEGIN RSA PUBLIC KEY-----") {
				foundPublic = true
			}
		}
	}

	// Check StringData first
	checkKeys(secret.StringData)

	// If not found in StringData, check Data
	if !foundPrivate || !foundPublic {
		data := make(map[string]string)
		for k, v := range secret.Data {
			data[k] = string(v)
		}
		checkKeys(data)
	}

	assert.True(t, foundPrivate, "No valid RSA private key found in secret")
	assert.True(t, foundPublic, "No valid RSA public key found in secret")

	// Verify that both keys have the same timestamp
	if foundPrivate && foundPublic {
		assert.Contains(t, secret.StringData, fmt.Sprintf("%s.pub.pem", timestamp), "Public key name does not match private key timestamp")
	}
}

func TestSecretGenerationForEditions(t *testing.T) {
	tests := []struct {
		name           string
		edition        string
		expectSecrets  bool
		secretsToCheck []string
	}{
		{
			name:           "EE Edition",
			edition:        "ee",
			expectSecrets:  true,
			secretsToCheck: []string{"openid-secret", "vault-secret"},
		},
		{
			name:           "CE Edition",
			edition:        "ce",
			expectSecrets:  false,
			secretsToCheck: []string{"openid-secret", "vault-secret"},
		},
		{
			name:           "No Edition Set",
			edition:        "",
			expectSecrets:  false,
			secretsToCheck: []string{"openid-secret", "vault-secret"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockClient := NewMockKubernetesClient()

			// No need to set up explicit mocks as we're using the real implementation with a fake clientset

			// Set required env vars
			cleanup := setTestEnv(tt.edition)
			defer cleanup()

			// Run the secret generation
			generateEESecrets(mockClient.KubernetesClient)

			// Verify secrets based on edition
			for _, secretName := range tt.secretsToCheck {
				secret, err := mockClient.Clientset.CoreV1().Secrets("test").Get(context.Background(), secretName, metav1.GetOptions{})

				if tt.expectSecrets {
					// For EE edition, verify secrets exist with correct format
					assert.NoError(t, err)
					assert.NotNil(t, secret)
					// Verify secret type
					assert.Equal(t, corev1.SecretTypeOpaque, secret.Type)

					// Verify there's exactly one key pair with correct format
					foundPrivate := false
					foundPublic := false
					timestamp := ""

					// Helper function to check keys in either StringData or Data
					checkKeys := func(data map[string]string) {
						for k, v := range data {
							if (strings.HasSuffix(k, ".prv.pem") || strings.HasSuffix(k, ".pem")) && strings.Contains(v, "-----BEGIN RSA PRIVATE KEY-----") {
								foundPrivate = true
								// Extract timestamp from the key name
								timestamp = strings.TrimSuffix(k, ".prv.pem")
							}
							if strings.HasSuffix(k, ".pub.pem") && strings.Contains(v, "-----BEGIN RSA PUBLIC KEY-----") {
								foundPublic = true
							}
						}
					}

					// Check StringData first
					checkKeys(secret.StringData)

					// If not found in StringData, check Data
					if !foundPrivate || !foundPublic {
						data := make(map[string]string)
						for k, v := range secret.Data {
							data[k] = string(v)
						}
						checkKeys(data)
					}

					assert.True(t, foundPrivate, "No valid RSA private key found in secret %s", secretName)
					if secretName == "vault-secret" {
						assert.True(t, foundPublic, "No valid RSA public key found in secret %s", secretName)
						assert.Contains(t, secret.StringData, fmt.Sprintf("%s.pub.pem", timestamp), "Public key name does not match private key timestamp for secret %s", secretName)
					}
				} else {
					// For non-EE editions, verify secrets don't exist
					assert.Error(t, err, "Secret %s should not exist", secretName)
				}
			}
		})
	}
}
