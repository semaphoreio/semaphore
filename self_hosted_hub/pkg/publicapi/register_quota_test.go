package publicapi

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	gosync "sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/feature"
	models "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/models"
	quotas "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/quotas"
	require "github.com/stretchr/testify/require"
	postgres "gorm.io/driver/postgres"
	gorm "gorm.io/gorm"
)

func Test__RegisterQuotaLookup(t *testing.T) {
	t.Run("quota lookup failure rejects registration", func(t *testing.T) {
		orgID := uuid.New()
		_, token, err := models.CreateAgentType(orgID, &testRequesterID, "s1-quota-error")
		require.NoError(t, err)

		server := newServerWithFeatureProvider(t, &stubFeatureProvider{err: errors.New("feature service unavailable")})
		res := runOn(server, orgID, "POST", "/register", token, registerRequest("quota-error-1"))
		require.Equal(t, http.StatusInternalServerError, res.Code)
		body, err := io.ReadAll(res.Body)
		require.NoError(t, err)
		require.Contains(t, string(body), "unknown agent quota for organization")
		requireRegisteredAgents(t, orgID, 0)
	})

	t.Run("feature not available rejects registration", func(t *testing.T) {
		orgID := uuid.New()
		_, token, err := models.CreateAgentType(orgID, &testRequesterID, "s1-quota-disabled")
		require.NoError(t, err)

		server := newServerWithFeatureProvider(t, &stubFeatureProvider{state: feature.Hidden})
		res := runOn(server, orgID, "POST", "/register", token, registerRequest("quota-disabled-1"))
		require.Equal(t, http.StatusUnprocessableEntity, res.Code)
		body, err := io.ReadAll(res.Body)
		require.NoError(t, err)
		require.Contains(t, string(body), ErrFeatureNotAvailable.Error())
		requireRegisteredAgents(t, orgID, 0)
	})

	t.Run("concurrent registrations do not go over the quota", func(t *testing.T) {
		orgID := uuid.New()
		_, token, err := models.CreateAgentType(orgID, &testRequesterID, "s1-quota-concurrent")
		require.NoError(t, err)

		server := newServerWithFeatureProvider(t, &stubFeatureProvider{quantity: 3})

		var wg gosync.WaitGroup
		codes := make(chan int, 10)
		for i := 0; i < 10; i++ {
			wg.Add(1)
			go func(i int) {
				defer wg.Done()
				res := runOn(server, orgID, "POST", "/register", token, registerRequest(fmt.Sprintf("concurrent-%d", i)))
				codes <- res.Code
			}(i)
		}

		wg.Wait()
		close(codes)

		created, rejected := 0, 0
		for code := range codes {
			switch code {
			case http.StatusCreated:
				created++
			case http.StatusUnprocessableEntity:
				rejected++
			default:
				t.Fatalf("unexpected status code %d", code)
			}
		}

		require.Equal(t, 3, created)
		require.Equal(t, 7, rejected)
		requireRegisteredAgents(t, orgID, 3)
	})

	t.Run("registration retry at the quota is still rejected", func(t *testing.T) {
		orgID := uuid.New()
		_, token, err := models.CreateAgentType(orgID, &testRequesterID, "s1-quota-retry")
		require.NoError(t, err)

		server := newServerWithFeatureProvider(t, &stubFeatureProvider{quantity: 1})
		res := runOn(server, orgID, "POST", "/register", token, registerRequest("quota-retry-1"))
		require.Equal(t, http.StatusCreated, res.Code)

		res = runOn(server, orgID, "POST", "/register", token, registerRequest("quota-retry-1"))
		require.Equal(t, http.StatusUnprocessableEntity, res.Code)
		requireRegisteredAgents(t, orgID, 1)
	})

	t.Run("registration retry below the quota returns the same agent", func(t *testing.T) {
		orgID := uuid.New()
		_, token, err := models.CreateAgentType(orgID, &testRequesterID, "s1-quota-retry-ok")
		require.NoError(t, err)

		server := newServerWithFeatureProvider(t, &stubFeatureProvider{quantity: 2})
		res := runOn(server, orgID, "POST", "/register", token, registerRequest("quota-retry-ok-1"))
		require.Equal(t, http.StatusCreated, res.Code)

		res = runOn(server, orgID, "POST", "/register", token, registerRequest("quota-retry-ok-1"))
		require.Equal(t, http.StatusCreated, res.Code)
		requireRegisteredAgents(t, orgID, 1)
	})

	t.Run("disconnected agents free their quota slot", func(t *testing.T) {
		orgID := uuid.New()
		_, token, err := models.CreateAgentTypeWithSettings(orgID, &testRequesterID, "s1-quota-free", models.AgentNameSettings{NameAssignmentOrigin: models.NameAssignmentOriginFromAgent, ReleaseNameAfter: 60})
		require.NoError(t, err)

		server := newServerWithFeatureProvider(t, &stubFeatureProvider{quantity: 1})
		res := runOn(server, orgID, "POST", "/register", token, registerRequest("quota-free-1"))
		require.Equal(t, http.StatusCreated, res.Code)

		res = runOn(server, orgID, "POST", "/register", token, registerRequest("quota-free-2"))
		require.Equal(t, http.StatusUnprocessableEntity, res.Code)

		agent, err := models.FindAgentByName(orgID.String(), "quota-free-1")
		require.NoError(t, err)
		require.NoError(t, agent.Disconnect())
		requireRegisteredAgents(t, orgID, 0)

		res = runOn(server, orgID, "POST", "/register", token, registerRequest("quota-free-2"))
		require.Equal(t, http.StatusCreated, res.Code)
		requireRegisteredAgents(t, orgID, 1)
	})

	t.Run("quota is looked up before the registration waits, and the count is checked after it", func(t *testing.T) {
		orgID := uuid.New()
		agentType, token, err := models.CreateAgentType(orgID, &testRequesterID, "s1-quota-lock")
		require.NoError(t, err)

		provider := &stubFeatureProvider{quantity: 1, calls: make(chan struct{}, 1)}
		server := newServerWithFeatureProvider(t, provider)

		// Another session is registering an agent for the same organization,
		// and holds the organization's agent count row until it commits.
		otherTx := openExternalConnection(t).Begin()
		require.NoError(t, otherTx.Error)
		require.NoError(t, otherTx.Exec(
			"INSERT INTO agents (organization_id, agent_type_name, name, token_hash, state) VALUES (?, ?, ?, ?, ?)",
			orgID.String(), agentType.Name, "quota-lock-0", "not-a-real-hash", models.AgentStateRegistered,
		).Error)

		done := make(chan *httptest.ResponseRecorder, 1)
		go func() {
			done <- runOn(server, orgID, "POST", "/register", token, registerRequest("quota-lock-1"))
		}()

		// The quota is fetched even though the other registration is in flight.
		select {
		case <-provider.calls:
		case <-time.After(5 * time.Second):
			otherTx.Rollback()
			<-done
			t.Fatal("quota was not looked up while another registration was in flight")
		}

		// The registration itself waits for the other one to finish.
		select {
		case <-done:
			otherTx.Rollback()
			t.Fatal("registration finished while another registration for the organization was in flight")
		case <-time.After(300 * time.Millisecond):
		}

		// The other registration takes the last available slot.
		require.NoError(t, otherTx.Commit().Error)

		// The agent count is checked after the wait, so the slot taken above is seen.
		select {
		case res := <-done:
			require.Equal(t, http.StatusUnprocessableEntity, res.Code)
			body, err := io.ReadAll(res.Body)
			require.NoError(t, err)
			require.Contains(t, string(body), ErrQuotaReached.Error())
		case <-time.After(10 * time.Second):
			t.Fatal("registration did not finish after the other registration committed")
		}

		requireRegisteredAgents(t, orgID, 1)
	})

	t.Run("registrations for other organizations do not wait", func(t *testing.T) {
		busyOrgID := uuid.New()
		busyType, _, err := models.CreateAgentType(busyOrgID, &testRequesterID, "s1-quota-busy")
		require.NoError(t, err)

		orgID := uuid.New()
		_, token, err := models.CreateAgentType(orgID, &testRequesterID, "s1-quota-free-org")
		require.NoError(t, err)

		server := newServerWithFeatureProvider(t, &stubFeatureProvider{quantity: 5})

		otherTx := openExternalConnection(t).Begin()
		require.NoError(t, otherTx.Error)
		defer otherTx.Rollback()
		require.NoError(t, otherTx.Exec(
			"INSERT INTO agents (organization_id, agent_type_name, name, token_hash, state) VALUES (?, ?, ?, ?, ?)",
			busyOrgID.String(), busyType.Name, "quota-busy-0", "not-a-real-hash", models.AgentStateRegistered,
		).Error)

		done := make(chan *httptest.ResponseRecorder, 1)
		go func() {
			done <- runOn(server, orgID, "POST", "/register", token, registerRequest("quota-free-org-1"))
		}()

		select {
		case res := <-done:
			require.Equal(t, http.StatusCreated, res.Code)
		case <-time.After(5 * time.Second):
			t.Fatal("registration waited for a registration in another organization")
		}

		requireRegisteredAgents(t, orgID, 1)
	})
}

type stubFeatureProvider struct {
	state    feature.State
	quantity uint32
	err      error
	calls    chan struct{}
}

func (p *stubFeatureProvider) ListFeatures(orgID string) ([]feature.OrganizationFeature, error) {
	return p.ListFeaturesWithContext(context.Background(), orgID)
}

func (p *stubFeatureProvider) ListFeaturesWithContext(ctx context.Context, orgID string) ([]feature.OrganizationFeature, error) {
	if p.calls != nil {
		select {
		case p.calls <- struct{}{}:
		default:
		}
	}

	if p.err != nil {
		return nil, p.err
	}

	return []feature.OrganizationFeature{
		{Name: quotas.SelfHostedAgentsFeature, State: p.state, Quantity: p.quantity},
	}, nil
}

// We don't use NewServer here because it starts the shared agent counter again.
func newServerWithFeatureProvider(t *testing.T, provider feature.Provider) *Server {
	quotaClient, err := quotas.NewQuotaClient(provider)
	require.NoError(t, err)

	server := &Server{
		quotaClient:           quotaClient,
		publisher:             publisher,
		agentCounter:          agentCounter,
		httpClient:            &http.Client{Timeout: 5 * time.Second},
		timeoutHandlerTimeout: 15 * time.Second,
	}

	server.InitRouter()
	return server
}

// A connection that does not share the application's connection pool,
// used to hold locks from a different database session.
func openExternalConnection(t *testing.T) *gorm.DB {
	dsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		os.Getenv("DB_HOST"),
		os.Getenv("DB_PORT"),
		os.Getenv("DB_USERNAME"),
		os.Getenv("DB_PASSWORD"),
		os.Getenv("DB_NAME"),
	)

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	require.NoError(t, err)

	t.Cleanup(func() {
		if sqlDB, err := db.DB(); err == nil {
			_ = sqlDB.Close()
		}
	})

	return db
}

func requireRegisteredAgents(t *testing.T, orgID uuid.UUID, expected int) {
	t.Helper()

	count, err := models.CountAgentsInOrganization(orgID.String())
	require.NoError(t, err)
	require.Equal(t, expected, count, "agents in the table")

	stored, err := models.RegisteredAgentCount(orgID)
	require.NoError(t, err)
	require.Equal(t, expected, stored, "stored agent count")
}
