package kubernetes

import (
	"context"
	"fmt"

	"github.com/semaphoreio/semaphore/bootstrapper/pkg/utils"
	log "github.com/sirupsen/logrus"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
)

type KubernetesClient struct {
	Clientset kubernetes.Interface
	Namespace string
}

func NewClient() *KubernetesClient {
	namespace := utils.AssertEnv("KUBERNETES_NAMESPACE")
	return NewClientWithClientset(defaultClientset(), namespace)
}

func NewClientWithClientset(clientset kubernetes.Interface, namespace string) *KubernetesClient {
	return &KubernetesClient{
		Clientset: clientset,
		Namespace: namespace,
	}
}

func defaultClientset() *kubernetes.Clientset {
	config, err := rest.InClusterConfig()
	if err != nil {
		log.Fatalf("Failed to get in-cluster config: %v", err)
	}

	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		log.Fatalf("Failed to create Kubernetes client: %v", err)
	}

	return clientset
}

// UpsertSecret creates a new secret with the given data if it doesn't exist, or updates an existing secret.
// It is a convenience wrapper around UpsertSecretWithLabels with empty labels.
func (c *KubernetesClient) UpsertSecret(secretName string, data map[string]string) error {
	return c.UpsertSecretWithLabels(secretName, data, map[string]string{})
}

// CreateSecretIfNotExists creates a new secret with the given data only if it doesn't already exist.
// If the secret already exists, this function does nothing and returns nil.
// It is a convenience wrapper around CreateSecretWithLabelsIfNotExists with empty labels.
func (c *KubernetesClient) CreateSecretIfNotExists(secretName string, data map[string]string) error {
	return c.CreateSecretWithLabelsIfNotExists(secretName, data, map[string]string{})
}

// CreateSecretWithLabelsIfNotExists creates a new secret with the given data and labels only if it doesn't already exist.
// If the secret already exists, this function does nothing and returns nil, preserving the existing secret's data and labels.
// This differs from UpsertSecretWithLabels which would update an existing secret's data and labels.
func (c *KubernetesClient) CreateSecretWithLabelsIfNotExists(secretName string, data map[string]string, labels map[string]string) error {
	// Check if secret exists
	_, err := c.Clientset.CoreV1().
		Secrets(c.Namespace).
		Get(context.Background(), secretName, metav1.GetOptions{})

	if err == nil {
		// Secret already exists, do nothing
		log.Infof("Secret %s already exists in namespace %s - not creating", secretName, c.Namespace)
		return nil
	}

	// Secret doesn't exist, create it
	return c.createSecret(secretName, data, labels)
}

// createSecret is an internal helper function that creates a new secret with the given name, data, and labels.
// It handles the common logic for creating a Kubernetes secret used by both UpsertSecretWithLabels and
// CreateSecretWithLabelsIfNotExists.
func (c *KubernetesClient) createSecret(secretName string, data map[string]string, labels map[string]string) error {
	log.Infof("Secret %s does not exist in namespace %s - creating a new one", secretName, c.Namespace)
	secret := &corev1.Secret{
		Type:       corev1.SecretTypeOpaque,
		StringData: data,
		ObjectMeta: metav1.ObjectMeta{
			Name:      secretName,
			Namespace: c.Namespace,
			Labels:    labels,
		},
	}

	_, err := c.Clientset.CoreV1().
		Secrets(c.Namespace).
		Create(context.Background(), secret, metav1.CreateOptions{})

	if err != nil {
		return fmt.Errorf("failed to create secret %s: %v", secretName, err)
	}

	return nil
}

// UpsertSecretWithLabels creates a new secret with the given data and labels if it doesn't exist,
// or updates an existing secret by merging the provided data and labels with the existing ones.
func (c *KubernetesClient) UpsertSecretWithLabels(secretName string, data map[string]string, labels map[string]string) error {
	secret, err := c.Clientset.CoreV1().
		Secrets(c.Namespace).
		Get(context.Background(), secretName, metav1.GetOptions{})

	if err != nil {
		// Secret doesn't exist, create it
		return c.createSecret(secretName, data, labels)
	}

	if secret.StringData == nil {
		secret.StringData = make(map[string]string)
	}

	for key, value := range data {
		secret.StringData[key] = value
	}

	if secret.Labels == nil {
		secret.Labels = make(map[string]string)
	}

	for key, value := range labels {
		secret.Labels[key] = value
	}

	// Ensure secret type is set
	secret.Type = corev1.SecretTypeOpaque

	_, err = c.Clientset.CoreV1().
		Secrets(c.Namespace).
		Update(context.Background(), secret, metav1.UpdateOptions{})

	if err != nil {
		return fmt.Errorf("failed to update secret %s: %v", secretName, err)
	}

	log.Infof("Secret %s updated", secretName)
	return nil
}

// GetKubeVersion returns the Kubernetes server version as a string.
// If there's an error getting the version, it returns an empty string and logs the error.
func (c *KubernetesClient) GetKubeVersion() string {
	serverVersion, err := c.Clientset.Discovery().ServerVersion()
	if err != nil {
		log.Errorf("Failed to get Kubernetes server version: %v", err)
		return ""
	}

	return serverVersion.String()
}
