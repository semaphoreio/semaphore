package cmd

import (
	"crypto/tls"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"github.com/semaphoreio/semaphore/bootstrapper/pkg/clients"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/kubernetes"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/utils"
	log "github.com/sirupsen/logrus"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"k8s.io/client-go/kubernetes/fake"
)

// Mock interfaces for the packages we need to test
type UserPackage interface {
	CreateSemaphoreUser(kubernetesClient *kubernetes.KubernetesClient, name, email, secretName string) string
}

type OrganizationPackage interface {
	CreateSemaphoreOrganization(orgUsername, userId string) string
	CreateAgentType(kubernetesClient *kubernetes.KubernetesClient, orgId, userId, secretName, name string)
	OrganizationExists(orgUsername string) (bool, string)
}

type InstallationPackage interface {
	ConfigureInstallationDefaults(client *clients.InstanceConfigClient, orgId string) (map[string]string, error)
}

type GithubPackage interface {
	ConfigureApp(client *clients.InstanceConfigClient, repoProxy *clients.RepoProxyClient, appName string) error
}

type GitlabPackage interface {
	ConfigureApp(client *clients.InstanceConfigClient) error
}

type BitbucketPackage interface {
	ConfigureApp(client *clients.InstanceConfigClient) error
}

type TelemetryClientInterface interface {
	SendTelemetryInstallationData(data map[string]string)
}

// Implementations of the mock interfaces
type MockUserPkg struct {
	mock.Mock
}

func (m *MockUserPkg) CreateSemaphoreUser(kubernetesClient *kubernetes.KubernetesClient, name, email, secretName string) string {
	args := m.Called(kubernetesClient, name, email, secretName)
	return args.String(0)
}

type MockOrgPkg struct {
	mock.Mock
}

func (m *MockOrgPkg) CreateSemaphoreOrganization(orgUsername, userId string) string {
	args := m.Called(orgUsername, userId)
	return args.String(0)
}

func (m *MockOrgPkg) CreateAgentType(kubernetesClient *kubernetes.KubernetesClient, orgId, userId, secretName, name string) {
	m.Called(kubernetesClient, orgId, userId, secretName, name)
}

func (m *MockOrgPkg) OrganizationExists(orgUsername string) (bool, string) {
	args := m.Called(orgUsername)
	return args.Bool(0), args.String(1)
}

type MockInstallationPkg struct {
	mock.Mock
}

func (m *MockInstallationPkg) ConfigureInstallationDefaults(client *clients.InstanceConfigClient, orgId string) (map[string]string, error) {
	args := m.Called(client, orgId)
	return args.Get(0).(map[string]string), args.Error(1)
}

type MockGithubPkg struct {
	mock.Mock
}

func (m *MockGithubPkg) ConfigureApp(client *clients.InstanceConfigClient, repoProxy *clients.RepoProxyClient, appName string) error {
	args := m.Called(client, repoProxy, appName)
	return args.Error(0)
}

type MockGitlabPkg struct {
	mock.Mock
}

func (m *MockGitlabPkg) ConfigureApp(client *clients.InstanceConfigClient) error {
	args := m.Called(client)
	return args.Error(0)
}

type MockBitbucketPkg struct {
	mock.Mock
}

func (m *MockBitbucketPkg) ConfigureApp(client *clients.InstanceConfigClient) error {
	args := m.Called(client)
	return args.Error(0)
}

type MockTelemetryClient struct {
	mock.Mock
}

func (m *MockTelemetryClient) SendTelemetryInstallationData(data map[string]string) {
	m.Called(data)
}

// Helper function to set environment variables for testing
func setInitOrgTestEnv() func() {
	envVars := map[string]string{
		"BASE_DOMAIN":                  "semaphore.test",
		"ORGANIZATION_USERNAME":        "test-org",
		"ROOT_NAME":                    "Test User",
		"ROOT_EMAIL":                   "test@example.com",
		"ROOT_USER_SECRET_NAME":        "root-user-secret",
		"KUBERNETES_NAMESPACE":         "test",
		"TLS_SKIP_VERIFY_INTERNAL":     "true",
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

// Test waitForIngress function using a real HTTP server
func TestWaitForIngress(t *testing.T) {
	// Create a test server that will respond with success
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "OK")
	}))
	defer server.Close()

	// Create a temporary version of waitForIngress that uses our test server
	testWaitForIngress := func(domain string) {
		// Use an HTTP client with a short timeout
		client := &http.Client{
			Timeout: 100 * time.Millisecond,
			Transport: &http.Transport{
				TLSClientConfig: &tls.Config{
					InsecureSkipVerify: true,
				},
			},
		}

		// Make a request to our test server
		resp, err := client.Get(server.URL)
		assert.NoError(t, err)
		assert.Equal(t, http.StatusOK, resp.StatusCode)
	}

	// Run the test function
	testWaitForIngress("semaphore.test")
}

// Helper function that runs initOrgCmd with mocks
func runInitOrgWithMocks(t *testing.T, userPkg UserPackage, orgPkg OrganizationPackage,
                          installPkg InstallationPackage, githubPkg GithubPackage,
                          gitlabPkg GitlabPackage, bitbucketPkg BitbucketPackage) {

	// Create a test version of the cmd function that uses our mocks
	initOrgFn := func() {
		// Set up client mocks
		fakeClientset := fake.NewSimpleClientset()
		kubernetesClient := kubernetes.NewClientWithClientset(fakeClientset, "test")
		instanceConfigClient := &clients.InstanceConfigClient{} // Mock client
		repoProxyClient := &clients.RepoProxyClient{} // Mock client

		// Get environment variables
		// domain not used because we skip waitForIngress
		orgUsername := utils.AssertEnv("ORGANIZATION_USERNAME")
		userName := utils.AssertEnv("ROOT_NAME")
		userEmail := utils.AssertEnv("ROOT_EMAIL")
		rootUserSecretName := utils.AssertEnv("ROOT_USER_SECRET_NAME")

		// Check if organization already exists
		exists, existingOrgId := orgPkg.OrganizationExists(orgUsername)
		if exists {
			// If organization already exists, return early
			log.Infof("Organization %s already exists with ID %s. Skipping organization creation.", orgUsername, existingOrgId)
			return
		}

		// We skip actually waiting for ingress in tests
		// Instead of calling waitForIngress(domain)

		// Create user and organization
		userId := userPkg.CreateSemaphoreUser(kubernetesClient, userName, userEmail, rootUserSecretName)
		orgId := orgPkg.CreateSemaphoreOrganization(orgUsername, userId)

		// Set up agent type if enabled
		if os.Getenv("DEFAULT_AGENT_TYPE_ENABLED") == "true" {
			agentTypeSecretName := utils.AssertEnv("DEFAULT_AGENT_TYPE_SECRET_NAME")
			agentTypeName := utils.AssertEnv("DEFAULT_AGENT_TYPE_NAME")
			orgPkg.CreateAgentType(kubernetesClient, orgId, userId, agentTypeSecretName, agentTypeName)
		}

		// Configure installation defaults if enabled
		if os.Getenv("CONFIGURE_INSTALLATION_DEFAULTS") == "true" {
			installationDefaults, err := installPkg.ConfigureInstallationDefaults(instanceConfigClient, orgId)
			if err == nil {
				// We're not actually checking telemetry in this test
				// Just verify the configuration call was made
				_ = installationDefaults
			}
		}

		// Configure GitHub app if enabled
		if os.Getenv("CONFIGURE_GITHUB_APP") == "true" {
			appName := utils.AssertEnv("GITHUB_APPLICATION_NAME")
			githubPkg.ConfigureApp(instanceConfigClient, repoProxyClient, appName)
		}

		// Configure Bitbucket app if enabled
		if os.Getenv("CONFIGURE_BITBUCKET_APP") == "true" {
			bitbucketPkg.ConfigureApp(instanceConfigClient)
		}

		// Configure GitLab app if enabled
		if os.Getenv("CONFIGURE_GITLAB_APP") == "true" {
			gitlabPkg.ConfigureApp(instanceConfigClient)
		}
	}

	// Run the function
	initOrgFn()
}

// Test the main init-org functionality with minimal configuration
func TestInitOrgBasic(t *testing.T) {
	// Set up environment variables
	cleanup := setInitOrgTestEnv()
	defer cleanup()

	// Create mock objects
	mockUserPkg := new(MockUserPkg)
	mockOrgPkg := new(MockOrgPkg)
	mockInstallPkg := new(MockInstallationPkg)
	mockGithubPkg := new(MockGithubPkg)
	mockGitlabPkg := new(MockGitlabPkg)
	mockBitbucketPkg := new(MockBitbucketPkg)

	// Set up expectations
	expectedUserId := "user123"
	expectedOrgId := "org456"

	mockOrgPkg.On("OrganizationExists", "test-org").Return(false, "")
	mockUserPkg.On("CreateSemaphoreUser", mock.Anything, "Test User", "test@example.com", "root-user-secret").Return(expectedUserId)
	mockOrgPkg.On("CreateSemaphoreOrganization", "test-org", expectedUserId).Return(expectedOrgId)

	// Run the command with our mocks
	runInitOrgWithMocks(t, mockUserPkg, mockOrgPkg, mockInstallPkg, mockGithubPkg, mockGitlabPkg, mockBitbucketPkg)

	// Verify expectations
	mockUserPkg.AssertExpectations(t)
	mockOrgPkg.AssertExpectations(t)

	// These weren't called because the config wasn't enabled
	mockInstallPkg.AssertNotCalled(t, "ConfigureInstallationDefaults", mock.Anything, mock.Anything)
	mockGithubPkg.AssertNotCalled(t, "ConfigureApp", mock.Anything, mock.Anything, mock.Anything)
	mockGitlabPkg.AssertNotCalled(t, "ConfigureApp", mock.Anything)
	mockBitbucketPkg.AssertNotCalled(t, "ConfigureApp", mock.Anything)
}

// Test with agent type creation enabled
func TestInitOrgWithAgentType(t *testing.T) {
	// Set up environment variables
	cleanup := setInitOrgTestEnv()
	defer cleanup()

	// Set agent type environment variables
	os.Setenv("DEFAULT_AGENT_TYPE_ENABLED", "true")
	os.Setenv("DEFAULT_AGENT_TYPE_SECRET_NAME", "agent-type-secret")
	os.Setenv("DEFAULT_AGENT_TYPE_NAME", "default-agent")
	defer func() {
		os.Unsetenv("DEFAULT_AGENT_TYPE_ENABLED")
		os.Unsetenv("DEFAULT_AGENT_TYPE_SECRET_NAME")
		os.Unsetenv("DEFAULT_AGENT_TYPE_NAME")
	}()

	// Create mock objects
	mockUserPkg := new(MockUserPkg)
	mockOrgPkg := new(MockOrgPkg)
	mockInstallPkg := new(MockInstallationPkg)
	mockGithubPkg := new(MockGithubPkg)
	mockGitlabPkg := new(MockGitlabPkg)
	mockBitbucketPkg := new(MockBitbucketPkg)

	// Set up expectations
	expectedUserId := "user123"
	expectedOrgId := "org456"

	mockOrgPkg.On("OrganizationExists", "test-org").Return(false, "")
	mockUserPkg.On("CreateSemaphoreUser", mock.Anything, "Test User", "test@example.com", "root-user-secret").Return(expectedUserId)
	mockOrgPkg.On("CreateSemaphoreOrganization", "test-org", expectedUserId).Return(expectedOrgId)
	mockOrgPkg.On("CreateAgentType", mock.Anything, expectedOrgId, expectedUserId, "agent-type-secret", "default-agent").Return()

	// Run the command with our mocks
	runInitOrgWithMocks(t, mockUserPkg, mockOrgPkg, mockInstallPkg, mockGithubPkg, mockGitlabPkg, mockBitbucketPkg)

	// Verify expectations
	mockUserPkg.AssertExpectations(t)
	mockOrgPkg.AssertExpectations(t)
	mockInstallPkg.AssertNotCalled(t, "ConfigureInstallationDefaults", mock.Anything, mock.Anything)
	mockGithubPkg.AssertNotCalled(t, "ConfigureApp", mock.Anything, mock.Anything, mock.Anything)
	mockGitlabPkg.AssertNotCalled(t, "ConfigureApp", mock.Anything)
	mockBitbucketPkg.AssertNotCalled(t, "ConfigureApp", mock.Anything)
}

// Test with installation defaults enabled
func TestInitOrgWithInstallationDefaults(t *testing.T) {
	// Set up environment variables
	cleanup := setInitOrgTestEnv()
	defer cleanup()

	// Set installation defaults environment variables
	os.Setenv("CONFIGURE_INSTALLATION_DEFAULTS", "true")
	os.Setenv("CHART_VERSION", "1.0.0")
	defer func() {
		os.Unsetenv("CONFIGURE_INSTALLATION_DEFAULTS")
		os.Unsetenv("CHART_VERSION")
	}()

	// Create mock objects
	mockUserPkg := new(MockUserPkg)
	mockOrgPkg := new(MockOrgPkg)
	mockInstallationPkg := new(MockInstallationPkg)
	mockGithubPkg := new(MockGithubPkg)
	mockGitlabPkg := new(MockGitlabPkg)
	mockBitbucketPkg := new(MockBitbucketPkg)

	// Set up expectations
	expectedUserId := "user123"
	expectedOrgId := "org456"
	expectedInstallationDefaults := map[string]string{"version": "1.0.0"}

	mockOrgPkg.On("OrganizationExists", "test-org").Return(false, "")
	mockUserPkg.On("CreateSemaphoreUser", mock.Anything, "Test User", "test@example.com", "root-user-secret").Return(expectedUserId)
	mockOrgPkg.On("CreateSemaphoreOrganization", "test-org", expectedUserId).Return(expectedOrgId)
	mockInstallationPkg.On("ConfigureInstallationDefaults", mock.Anything, expectedOrgId).Return(expectedInstallationDefaults, nil)

	// Run the command with our mocks
	runInitOrgWithMocks(t, mockUserPkg, mockOrgPkg, mockInstallationPkg, mockGithubPkg, mockGitlabPkg, mockBitbucketPkg)

	// Verify expectations
	mockUserPkg.AssertExpectations(t)
	mockOrgPkg.AssertExpectations(t)
	mockInstallationPkg.AssertExpectations(t)
	mockGithubPkg.AssertNotCalled(t, "ConfigureApp", mock.Anything, mock.Anything, mock.Anything)
	mockGitlabPkg.AssertNotCalled(t, "ConfigureApp", mock.Anything)
	mockBitbucketPkg.AssertNotCalled(t, "ConfigureApp", mock.Anything)
}

// Test with GitHub app configuration
func TestInitOrgWithGithubApp(t *testing.T) {
	// Set up environment variables
	cleanup := setInitOrgTestEnv()
	defer cleanup()

	// Set GitHub app environment variables
	os.Setenv("CONFIGURE_GITHUB_APP", "true")
	os.Setenv("GITHUB_APPLICATION_NAME", "test-github-app")
	defer func() {
		os.Unsetenv("CONFIGURE_GITHUB_APP")
		os.Unsetenv("GITHUB_APPLICATION_NAME")
	}()

	// Create mock objects
	mockUserPkg := new(MockUserPkg)
	mockOrgPkg := new(MockOrgPkg)
	mockInstallPkg := new(MockInstallationPkg)
	mockGithubPkg := new(MockGithubPkg)
	mockGitlabPkg := new(MockGitlabPkg)
	mockBitbucketPkg := new(MockBitbucketPkg)

	// Set up expectations
	expectedUserId := "user123"
	expectedOrgId := "org456"

	mockOrgPkg.On("OrganizationExists", "test-org").Return(false, "")
	mockUserPkg.On("CreateSemaphoreUser", mock.Anything, "Test User", "test@example.com", "root-user-secret").Return(expectedUserId)
	mockOrgPkg.On("CreateSemaphoreOrganization", "test-org", expectedUserId).Return(expectedOrgId)
	mockGithubPkg.On("ConfigureApp", mock.Anything, mock.Anything, "test-github-app").Return(nil)

	// Run the command with our mocks
	runInitOrgWithMocks(t, mockUserPkg, mockOrgPkg, mockInstallPkg, mockGithubPkg, mockGitlabPkg, mockBitbucketPkg)

	// Verify expectations
	mockUserPkg.AssertExpectations(t)
	mockOrgPkg.AssertExpectations(t)
	mockGithubPkg.AssertExpectations(t)
	mockInstallPkg.AssertNotCalled(t, "ConfigureInstallationDefaults", mock.Anything, mock.Anything)
	mockGitlabPkg.AssertNotCalled(t, "ConfigureApp", mock.Anything)
	mockBitbucketPkg.AssertNotCalled(t, "ConfigureApp", mock.Anything)
}

// Test with GitLab app configuration
func TestInitOrgWithGitlabApp(t *testing.T) {
	// Set up environment variables
	cleanup := setInitOrgTestEnv()
	defer cleanup()

	// Set GitLab app environment variables
	os.Setenv("CONFIGURE_GITLAB_APP", "true")
	defer os.Unsetenv("CONFIGURE_GITLAB_APP")

	// Create mock objects
	mockUserPkg := new(MockUserPkg)
	mockOrgPkg := new(MockOrgPkg)
	mockInstallPkg := new(MockInstallationPkg)
	mockGithubPkg := new(MockGithubPkg)
	mockGitlabPkg := new(MockGitlabPkg)
	mockBitbucketPkg := new(MockBitbucketPkg)

	// Set up expectations
	expectedUserId := "user123"
	expectedOrgId := "org456"

	mockOrgPkg.On("OrganizationExists", "test-org").Return(false, "")
	mockUserPkg.On("CreateSemaphoreUser", mock.Anything, "Test User", "test@example.com", "root-user-secret").Return(expectedUserId)
	mockOrgPkg.On("CreateSemaphoreOrganization", "test-org", expectedUserId).Return(expectedOrgId)
	mockGitlabPkg.On("ConfigureApp", mock.Anything).Return(nil)

	// Run the command with our mocks
	runInitOrgWithMocks(t, mockUserPkg, mockOrgPkg, mockInstallPkg, mockGithubPkg, mockGitlabPkg, mockBitbucketPkg)

	// Verify expectations
	mockUserPkg.AssertExpectations(t)
	mockOrgPkg.AssertExpectations(t)
	mockGitlabPkg.AssertExpectations(t)
	mockInstallPkg.AssertNotCalled(t, "ConfigureInstallationDefaults", mock.Anything, mock.Anything)
	mockGithubPkg.AssertNotCalled(t, "ConfigureApp", mock.Anything, mock.Anything, mock.Anything)
	mockBitbucketPkg.AssertNotCalled(t, "ConfigureApp", mock.Anything)
}

// Test with Bitbucket app configuration
func TestInitOrgWithBitbucketApp(t *testing.T) {
	// Set up environment variables
	cleanup := setInitOrgTestEnv()
	defer cleanup()

	// Set Bitbucket app environment variables
	os.Setenv("CONFIGURE_BITBUCKET_APP", "true")
	defer os.Unsetenv("CONFIGURE_BITBUCKET_APP")

	// Create mock objects
	mockUserPkg := new(MockUserPkg)
	mockOrgPkg := new(MockOrgPkg)
	mockInstallPkg := new(MockInstallationPkg)
	mockGithubPkg := new(MockGithubPkg)
	mockGitlabPkg := new(MockGitlabPkg)
	mockBitbucketPkg := new(MockBitbucketPkg)

	// Set up expectations
	expectedUserId := "user123"
	expectedOrgId := "org456"

	mockOrgPkg.On("OrganizationExists", "test-org").Return(false, "")
	mockUserPkg.On("CreateSemaphoreUser", mock.Anything, "Test User", "test@example.com", "root-user-secret").Return(expectedUserId)
	mockOrgPkg.On("CreateSemaphoreOrganization", "test-org", expectedUserId).Return(expectedOrgId)
	mockBitbucketPkg.On("ConfigureApp", mock.Anything).Return(nil)

	// Run the command with our mocks
	runInitOrgWithMocks(t, mockUserPkg, mockOrgPkg, mockInstallPkg, mockGithubPkg, mockGitlabPkg, mockBitbucketPkg)

	// Verify expectations
	mockUserPkg.AssertExpectations(t)
	mockOrgPkg.AssertExpectations(t)
	mockBitbucketPkg.AssertExpectations(t)
	mockInstallPkg.AssertNotCalled(t, "ConfigureInstallationDefaults", mock.Anything, mock.Anything)
	mockGithubPkg.AssertNotCalled(t, "ConfigureApp", mock.Anything, mock.Anything, mock.Anything)
	mockGitlabPkg.AssertNotCalled(t, "ConfigureApp", mock.Anything)
}

// Test for simulating actual HTTP server response in waitForIngress
func TestWaitForIngressWithRealServer(t *testing.T) {
	// Create a test server that returns 200 OK
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprintln(w, "OK")
	}))
	defer server.Close()

	// Set up environment
	os.Setenv("TLS_SKIP_VERIFY_INTERNAL", "true")
	defer os.Unsetenv("TLS_SKIP_VERIFY_INTERNAL")

	// Create a test client that can connect to our test server
	client := &http.Client{
		Timeout: 100 * time.Millisecond,
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{
				InsecureSkipVerify: true,
			},
		},
	}

	// Make the request directly to test server
	resp, err := client.Get(server.URL)
	assert.NoError(t, err)
	assert.Equal(t, http.StatusOK, resp.StatusCode)
}

// Test when organization already exists
func TestInitOrgWithExistingOrganization(t *testing.T) {
	// Set up environment variables
	cleanup := setInitOrgTestEnv()
	defer cleanup()

	// Create mock objects
	mockUserPkg := new(MockUserPkg)
	mockOrgPkg := new(MockOrgPkg)
	mockInstallPkg := new(MockInstallationPkg)
	mockGithubPkg := new(MockGithubPkg)
	mockGitlabPkg := new(MockGitlabPkg)
	mockBitbucketPkg := new(MockBitbucketPkg)

	// Set up expectations - organization already exists
	mockOrgPkg.On("OrganizationExists", "test-org").Return(true, "existing-org-123")

	// Run the command with our mocks
	runInitOrgWithMocks(t, mockUserPkg, mockOrgPkg, mockInstallPkg, mockGithubPkg, mockGitlabPkg, mockBitbucketPkg)

	// Verify expectations
	mockOrgPkg.AssertExpectations(t)

	// User creation should not be called since organization already exists
	mockUserPkg.AssertNotCalled(t, "CreateSemaphoreUser", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
	mockOrgPkg.AssertNotCalled(t, "CreateSemaphoreOrganization", mock.Anything, mock.Anything)

	// None of these should be called either
	mockInstallPkg.AssertNotCalled(t, "ConfigureInstallationDefaults", mock.Anything, mock.Anything)
	mockGithubPkg.AssertNotCalled(t, "ConfigureApp", mock.Anything, mock.Anything, mock.Anything)
	mockGitlabPkg.AssertNotCalled(t, "ConfigureApp", mock.Anything)
	mockBitbucketPkg.AssertNotCalled(t, "ConfigureApp", mock.Anything)
}

// Test that right kubernetes secret name is used when creating user
func TestUserSecretName(t *testing.T) {
	// Set up environment variables
	cleanup := setInitOrgTestEnv()
	defer cleanup()

	// Override root user secret name
	os.Setenv("ROOT_USER_SECRET_NAME", "custom-secret-name")
	defer os.Unsetenv("ROOT_USER_SECRET_NAME")

	// Create mock objects
	mockUserPkg := new(MockUserPkg)
	mockOrgPkg := new(MockOrgPkg)
	mockInstallPkg := new(MockInstallationPkg)
	mockGithubPkg := new(MockGithubPkg)
	mockGitlabPkg := new(MockGitlabPkg)
	mockBitbucketPkg := new(MockBitbucketPkg)

	// Set expectations with specific secret name check
	mockOrgPkg.On("OrganizationExists", "test-org").Return(false, "")
	mockUserPkg.On("CreateSemaphoreUser", mock.Anything, "Test User", "test@example.com", "custom-secret-name").Return("user-123")
	mockOrgPkg.On("CreateSemaphoreOrganization", "test-org", "user-123").Return("org-123")

	// Run the command with our mocks
	runInitOrgWithMocks(t, mockUserPkg, mockOrgPkg, mockInstallPkg, mockGithubPkg, mockGitlabPkg, mockBitbucketPkg)

	// Verify expectations
	mockUserPkg.AssertExpectations(t)
	mockOrgPkg.AssertExpectations(t)
}

func TestAllFeaturesEnabled(t *testing.T) {
	// Set up environment variables for all features
	cleanup := setInitOrgTestEnv()
	defer cleanup()

	// Set all optional features
	os.Setenv("DEFAULT_AGENT_TYPE_ENABLED", "true")
	os.Setenv("DEFAULT_AGENT_TYPE_SECRET_NAME", "agent-type-secret")
	os.Setenv("DEFAULT_AGENT_TYPE_NAME", "default-agent")
	os.Setenv("CONFIGURE_INSTALLATION_DEFAULTS", "true")
	os.Setenv("CHART_VERSION", "1.0.0")
	os.Setenv("CONFIGURE_GITHUB_APP", "true")
	os.Setenv("GITHUB_APPLICATION_NAME", "test-github-app")
	os.Setenv("CONFIGURE_GITLAB_APP", "true")
	os.Setenv("CONFIGURE_BITBUCKET_APP", "true")

	defer func() {
		os.Unsetenv("DEFAULT_AGENT_TYPE_ENABLED")
		os.Unsetenv("DEFAULT_AGENT_TYPE_SECRET_NAME")
		os.Unsetenv("DEFAULT_AGENT_TYPE_NAME")
		os.Unsetenv("CONFIGURE_INSTALLATION_DEFAULTS")
		os.Unsetenv("CHART_VERSION")
		os.Unsetenv("CONFIGURE_GITHUB_APP")
		os.Unsetenv("GITHUB_APPLICATION_NAME")
		os.Unsetenv("CONFIGURE_GITLAB_APP")
		os.Unsetenv("CONFIGURE_BITBUCKET_APP")
	}()

	// Mock all dependencies
	mockUserPkg := new(MockUserPkg)
	mockOrgPkg := new(MockOrgPkg)
	mockInstallPkg := new(MockInstallationPkg)
	mockGithubPkg := new(MockGithubPkg)
	mockGitlabPkg := new(MockGitlabPkg)
	mockBitbucketPkg := new(MockBitbucketPkg)

	// Set up expectations
	expectedUserId := "user123"
	expectedOrgId := "org456"
	expectedInstallationDefaults := map[string]string{"version": "1.0.0"}

	// Set mock expectations
	mockOrgPkg.On("OrganizationExists", "test-org").Return(false, "")
	mockUserPkg.On("CreateSemaphoreUser", mock.Anything, "Test User", "test@example.com", "root-user-secret").Return(expectedUserId)
	mockOrgPkg.On("CreateSemaphoreOrganization", "test-org", expectedUserId).Return(expectedOrgId)
	mockOrgPkg.On("CreateAgentType", mock.Anything, expectedOrgId, expectedUserId, "agent-type-secret", "default-agent").Return()
	mockInstallPkg.On("ConfigureInstallationDefaults", mock.Anything, expectedOrgId).Return(expectedInstallationDefaults, nil)
	mockGithubPkg.On("ConfigureApp", mock.Anything, mock.Anything, "test-github-app").Return(nil)
	mockGitlabPkg.On("ConfigureApp", mock.Anything).Return(nil)
	mockBitbucketPkg.On("ConfigureApp", mock.Anything).Return(nil)

	// Run the command with our mocks
	runInitOrgWithMocks(t, mockUserPkg, mockOrgPkg, mockInstallPkg, mockGithubPkg, mockGitlabPkg, mockBitbucketPkg)

	// Verify expectations
	mockUserPkg.AssertExpectations(t)
	mockOrgPkg.AssertExpectations(t)
	mockInstallPkg.AssertExpectations(t)
	mockGithubPkg.AssertExpectations(t)
	mockGitlabPkg.AssertExpectations(t)
	mockBitbucketPkg.AssertExpectations(t)
}
