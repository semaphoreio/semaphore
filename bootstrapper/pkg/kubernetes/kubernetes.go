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

func (c *KubernetesClient) UpsertSecret(secretName string, data map[string]string) error {
	return c.UpsertSecretWithLabels(secretName, data, map[string]string{})
}

func (c *KubernetesClient) UpsertSecretWithLabels(secretName string, data map[string]string, labels map[string]string) error {
	secret, err := c.Clientset.CoreV1().
		Secrets(c.Namespace).
		Get(context.Background(), secretName, metav1.GetOptions{})

	if err != nil {
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

		_, err = c.Clientset.CoreV1().
			Secrets(c.Namespace).
			Create(context.Background(), secret, metav1.CreateOptions{})

		if err != nil {
			return fmt.Errorf("failed to create secret %s: %v", secretName, err)
		}

		return nil
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
