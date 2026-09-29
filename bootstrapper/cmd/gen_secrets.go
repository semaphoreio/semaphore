package cmd

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/pem"
	"fmt"
	"log"
	"os"
	"strconv"
	"time"

	"github.com/semaphoreio/semaphore/bootstrapper/pkg/kubernetes"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/random"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/utils"
	"github.com/spf13/cobra"
)

var genSecretsCmd = &cobra.Command{
	Use:   "gen-secrets",
	Short: "Generate installation secrets",
	Args:  cobra.NoArgs,
	Long:  ``,
	Run: func(cmd *cobra.Command, args []string) {
		client := kubernetes.NewClient()
		generateJWTSecret(client)
		generateAuthenticationSecret(client)
		generateEncryptionKey(client)
		generateEESecrets(client)
	},
}

func generateJWTSecret(client *kubernetes.KubernetesClient) {
	secretName := utils.AssertEnv("JWT_SECRET_NAME")
	err := client.CreateSecretIfNotExists(secretName, map[string]string{
		"logs":      random.Base64String(32),
		"artifacts": random.Base64String(32),
	})

	if err != nil {
		log.Fatalf("Failed to generate JWT secrets: %v", err)
	}
}

func generateAuthenticationSecret(client *kubernetes.KubernetesClient) {
	secretName := utils.AssertEnv("AUTHENTICATION_SECRET_NAME")
	err := client.CreateSecretIfNotExists(secretName, map[string]string{
		"SESSION_SECRET_KEY_BASE":   random.Base64String(64),
		"TOKEN_HASHING_SALT":        random.Base64String(32),
		"OIDC_CLIENT_SECRET":        random.Base64String(32),
		"OIDC_MANAGE_CLIENT_SECRET": random.Base64String(32),
		"KC_ADMIN_LOGIN":            random.Base64String(32),
		"KC_ADMIN_PASSWORD":         random.Base64String(32),
		"MCP_OAUTH_JWT_KEYS":        random.Base64String(32),
	})

	if err != nil {
		log.Fatalf("Failed to generate authentication secrets: %v", err)
	}
}

func generateEncryptionKey(client *kubernetes.KubernetesClient) {
	secretName := utils.AssertEnv("ENCRYPTION_SECRET_NAME")
	err := client.CreateSecretIfNotExists(secretName, map[string]string{
		"key": random.Base64String(32),
	})

	if err != nil {
		log.Fatalf("Failed to generate encryption key: %v", err)
	}
}

func generateRSAKeyPair() ([]byte, []byte, error) {
	privateKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to generate RSA key: %v", err)
	}

	// Generate private key PEM
	privateKeyPEM := &pem.Block{
		Type:  "RSA PRIVATE KEY",
		Bytes: x509.MarshalPKCS1PrivateKey(privateKey),
	}

	// Generate public key PEM
	publicKeyPEM := &pem.Block{
		Type:  "RSA PUBLIC KEY",
		Bytes: x509.MarshalPKCS1PublicKey(&privateKey.PublicKey),
	}

	return pem.EncodeToMemory(privateKeyPEM), pem.EncodeToMemory(publicKeyPEM), nil
}

func generateOpenIDSecret(client *kubernetes.KubernetesClient) error {
	secretName := utils.AssertEnv("OPENID_SECRET_NAME")

	privateKey, _, err := generateRSAKeyPair()
	if err != nil {
		return fmt.Errorf("failed to generate OpenID RSA key pair: %v", err)
	}

	timestamp := strconv.FormatInt(time.Now().Unix(), 10)
	privateKeyName := fmt.Sprintf("%s.pem", timestamp)

	err = client.CreateSecretIfNotExists(secretName, map[string]string{
		privateKeyName: string(privateKey),
	})

	if err != nil {
		return fmt.Errorf("failed to generate OpenID secret: %v", err)
	}
	return nil
}

func generateVaultSecret(client *kubernetes.KubernetesClient) error {
	secretName := utils.AssertEnv("VAULT_SECRET_NAME")

	privateKey, publicKey, err := generateRSAKeyPair()
	if err != nil {
		return fmt.Errorf("failed to generate Vault RSA key pair: %v", err)
	}

	timestamp := strconv.FormatInt(time.Now().Unix(), 10)
	privateKeyName := fmt.Sprintf("%s.prv.pem", timestamp)
	publicKeyName := fmt.Sprintf("%s.pub.pem", timestamp)

	err = client.CreateSecretIfNotExists(secretName, map[string]string{
		privateKeyName: string(privateKey),
		publicKeyName:  string(publicKey),
	})

	if err != nil {
		return fmt.Errorf("failed to generate Vault secret: %v", err)
	}
	return nil
}

// runSecretGeneration handles the actual secret generation logic, allowing for dependency injection in tests
func generateEESecrets(client *kubernetes.KubernetesClient) {
	// Only generate OpenID and Vault secrets for EE edition
	edition := os.Getenv("SEMAPHORE_EDITION")
	if edition != "ee" {
		return
	}

	if err := generateOpenIDSecret(client); err != nil {
		log.Fatalf("Failed to generate OpenID secret: %v", err)
	}
	if err := generateVaultSecret(client); err != nil {
		log.Fatalf("Failed to generate Vault secret: %v", err)
	}
}

func init() {
	RootCmd.AddCommand(genSecretsCmd)
}
