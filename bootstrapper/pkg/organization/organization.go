package organization

import (
	"time"

	"github.com/semaphoreio/semaphore/bootstrapper/pkg/clients"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/config"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/kubernetes"
	sh "github.com/semaphoreio/semaphore/bootstrapper/pkg/protos/self_hosted"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/retry"
	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

func CreateSemaphoreOrganization(orgUsername, userId string) string {
	conn, err := grpc.NewClient(config.OrgEndpoint(), grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Fatalf("Failed to connect to org service: %v", err)
	}

	defer conn.Close()
	orgClient := clients.NewOrgClient(conn)

	var orgId string
	err = retry.WithConstantWait("organization creation", 5, 10*time.Second, func() error {
		org, err := orgClient.Create(userId, orgUsername, orgUsername)
		if err != nil {
			return err
		}

		orgId = org.GetOrgId()
		return nil
	})

	if err != nil {
		log.Fatalf("Failed to create organization: %v", err)
	}

	return orgId
}

func CreateAgentType(kubernetesClient *kubernetes.KubernetesClient, orgId, userId, secretName, name string) {
	conn, err := grpc.NewClient(config.SelfHostedEndpoint(), grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Fatalf("Failed to connect to self-hosted service: %v", err)
	}

	defer conn.Close()
	selfHostedClient := clients.NewSelfHostedClient(conn)

	var response *sh.CreateResponse
	err = retry.WithConstantWait("self-hosted agent creation", 5, 10*time.Second, func() error {
		r, err := selfHostedClient.Create(orgId, userId, name)
		if err != nil {
			return err
		}

		response = r
		return nil
	})

	if err != nil {
		log.Fatalf("Failed to create self-hosted agent: %v", err)
	}

	data := map[string]string{
		"agentTypeName":     response.AgentType.Name,
		"registrationToken": response.AgentRegistrationToken,
	}

	labels := map[string]string{
		"semaphoreci.com/resource-type": "agent-type-configuration",
	}

	err = kubernetesClient.UpsertSecretWithLabels(secretName, data, labels)
	if err != nil {
		log.Fatalf("Failed to upsert agent type secret: %v", err)
	}
}
