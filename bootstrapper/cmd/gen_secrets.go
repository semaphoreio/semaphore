package cmd

import (
	"log"

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
	},
}

func generateJWTSecret(client *kubernetes.KubernetesClient) {
	secretName := utils.AssertEnv("JWT_SECRET_NAME")
	err := client.UpsertSecret(secretName, map[string]string{
		"logs":      random.Base64String(32),
		"artifacts": random.Base64String(32),
	})

	if err != nil {
		log.Fatalf("Failed to generate JWT secrets: %v", err)
	}
}

func generateAuthenticationSecret(client *kubernetes.KubernetesClient) {
	secretName := utils.AssertEnv("AUTHENTICATION_SECRET_NAME")
	err := client.UpsertSecret(secretName, map[string]string{
		"SESSION_SECRET_KEY_BASE":   random.Base64String(64),
		"TOKEN_HASHING_SALT":        random.Base64String(32),
		"OIDC_CLIENT_SECRET":        random.Base64String(32),
		"OIDC_MANAGE_CLIENT_SECRET": random.Base64String(32),
		"KC_ADMIN_LOGIN":            random.Base64String(32),
		"KC_ADMIN_PASSWORD":         random.Base64String(32),
	})

	if err != nil {
		log.Fatalf("Failed to generate JWT secrets: %v", err)
	}
}

func generateEncryptionKey(client *kubernetes.KubernetesClient) {
	secretName := utils.AssertEnv("ENCRYPTION_SECRET_NAME")
	err := client.UpsertSecret(secretName, map[string]string{
		"key": random.Base64String(32),
	})

	if err != nil {
		log.Fatalf("Failed to generate encryption key: %v", err)
	}
}

func init() {
	RootCmd.AddCommand(genSecretsCmd)
}
