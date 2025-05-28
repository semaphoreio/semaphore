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
	originalKeyName := ""

	// Helper function to check keys in either StringData or Data
	checkKeys := func(data map[string]string) {
		for k, v := range data {
			if strings.HasSuffix(k, ".pem") && strings.Contains(v, "-----BEGIN RSA PRIVATE KEY-----") {
				foundPrivate = true
				originalKeyName = k
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

	// Now test that calling it again doesn't change the secret
	err = generateOpenIDSecret(mockClient.KubernetesClient)
	assert.NoError(t, err)

	// Get the secret again
	updatedSecret, err := mockClient.Clientset.CoreV1().Secrets("test").Get(context.Background(), "openid-secret", metav1.GetOptions{})
	assert.NoError(t, err)

	// Verify the original key is still there and no new key was added
	found := false
	keyCount := 0

	// Check in StringData or Data
	if len(updatedSecret.StringData) > 0 {
		keyCount = len(updatedSecret.StringData)
		_, found = updatedSecret.StringData[originalKeyName]
	} else if len(updatedSecret.Data) > 0 {
		keyCount = len(updatedSecret.Data)
		_, found = updatedSecret.Data[originalKeyName]
	}

	assert.True(t, found, "Original key should still be present")
	assert.Equal(t, 1, keyCount, "There should still be only one key")
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
	originalPrivateKey := ""
	originalPublicKey := ""

	// Helper function to check keys in either StringData or Data
	checkKeys := func(data map[string]string) {
		for k, v := range data {
			if strings.HasSuffix(k, ".prv.pem") && strings.Contains(v, "-----BEGIN RSA PRIVATE KEY-----") {
				foundPrivate = true
				// Extract timestamp from the key name
				timestamp = strings.TrimSuffix(k, ".prv.pem")
				originalPrivateKey = k
			}
			if strings.HasSuffix(k, ".pub.pem") && strings.Contains(v, "-----BEGIN RSA PUBLIC KEY-----") {
				foundPublic = true
				originalPublicKey = k
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

	// Test CreateSecretIfNotExists behavior by calling generateVaultSecret again
	err = generateVaultSecret(mockClient.KubernetesClient)
	assert.NoError(t, err)

	// Get the secret again
	updatedSecret, err := mockClient.Clientset.CoreV1().Secrets("test").Get(context.Background(), utils.AssertEnv("VAULT_SECRET_NAME"), metav1.GetOptions{})
	assert.NoError(t, err)

	// Verify the original keys are still there and no new keys were added
	foundOrigPrivate := false
	foundOrigPublic := false
	keyCount := 0

	// Check in StringData or Data
	if len(updatedSecret.StringData) > 0 {
		keyCount = len(updatedSecret.StringData)
		_, foundOrigPrivate = updatedSecret.StringData[originalPrivateKey]
		_, foundOrigPublic = updatedSecret.StringData[originalPublicKey]
	} else if len(updatedSecret.Data) > 0 {
		keyCount = len(updatedSecret.Data)
		_, foundOrigPrivate = updatedSecret.Data[originalPrivateKey]
		_, foundOrigPublic = updatedSecret.Data[originalPublicKey]
	}

	assert.True(t, foundOrigPrivate, "Original private key should still be present")
	assert.True(t, foundOrigPublic, "Original public key should still be present")
	assert.Equal(t, 2, keyCount, "There should still be exactly two keys")
}

func TestBasicSecretsGeneration(t *testing.T) {
	// Set required env vars
	cleanup := setTestEnv("")
	defer cleanup()

	mockClient := NewMockKubernetesClient()

	// First generation of secrets
	generateJWTSecret(mockClient.KubernetesClient)
	generateAuthenticationSecret(mockClient.KubernetesClient)
	generateEncryptionKey(mockClient.KubernetesClient)

	// Verify the secrets were created
	secretNames := []string{
		utils.AssertEnv("JWT_SECRET_NAME"),
		utils.AssertEnv("AUTHENTICATION_SECRET_NAME"),
		utils.AssertEnv("ENCRYPTION_SECRET_NAME"),
	}

	for _, secretName := range secretNames {
		secret, err := mockClient.Clientset.CoreV1().Secrets("test").Get(context.Background(), secretName, metav1.GetOptions{})
		assert.NoError(t, err)
		assert.NotNil(t, secret)

		// Store original data for comparison
		originalData := make(map[string]string)
		if len(secret.StringData) > 0 {
			for k, v := range secret.StringData {
				originalData[k] = v
			}
		} else if len(secret.Data) > 0 {
			for k, v := range secret.Data {
				originalData[k] = string(v)
			}
		}

		// Call generation functions again
		generateJWTSecret(mockClient.KubernetesClient)
		generateAuthenticationSecret(mockClient.KubernetesClient)
		generateEncryptionKey(mockClient.KubernetesClient)

		// Verify secrets haven't changed
		updatedSecret, err := mockClient.Clientset.CoreV1().Secrets("test").Get(context.Background(), secretName, metav1.GetOptions{})
		assert.NoError(t, err)

		// Check that data is the same
		if len(updatedSecret.StringData) > 0 {
			for k, v := range updatedSecret.StringData {
				assert.Equal(t, originalData[k], v, "Secret data should not have changed for %s", secretName)
			}
		} else if len(updatedSecret.Data) > 0 {
			for k, v := range updatedSecret.Data {
				assert.Equal(t, originalData[k], string(v), "Secret data should not have changed for %s", secretName)
			}
		}
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
