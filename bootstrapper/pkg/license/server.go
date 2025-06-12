package license

import (
	"context"
	"os"
	"time"

	"github.com/semaphoreio/semaphore/bootstrapper/pkg/clients"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/config"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/kubernetes"
	protoLicense "github.com/semaphoreio/semaphore/bootstrapper/pkg/protos/license"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	log "github.com/sirupsen/logrus"
)

const (
	cachedResponseDuration = 5 * time.Minute
	cachedRequestDuration  = 20 * time.Minute
	maxUsers               = 100
)

type Server struct {
	protoLicense.UnimplementedLicenseServiceServer
	licenseClient *Client
	licenseFile   string

	dataCollector dataCollector

	// Cache for valid license responses
	lastValidResponse     *protoLicense.VerifyLicenseResponse
	lastValidResponseTime time.Time
	lastValidRequest      *LicenseVerificationRequest
	lastValidRequestTime  time.Time
}

func NewServer(licenseServerURL, licenseFile string) *Server {
	return &Server{
		licenseClient: NewClient(licenseServerURL, nil),
		licenseFile:   licenseFile,
		dataCollector: &appDataCollector{},
	}
}

func RegisterServer(s *grpc.Server, server *Server) {
	protoLicense.RegisterLicenseServiceServer(s, server)
}

func (s *Server) VerifyLicense(ctx context.Context, req *protoLicense.VerifyLicenseRequest) (*protoLicense.VerifyLicenseResponse, error) {
	// Check cache first
	if s.lastValidResponse != nil && time.Since(s.lastValidResponseTime) < cachedResponseDuration {
		return s.lastValidResponse, nil
	}

	// Read license from file
	licenseBytes, err := os.ReadFile(s.licenseFile)
	if err != nil {
		return nil, status.Errorf(codes.FailedPrecondition, "failed to read license file: %v", err)
	}
	license := string(licenseBytes)

	if license == "" {
		return nil, status.Error(codes.FailedPrecondition, "license not found")
	}

	// Create verification request
	verificationReq := s.createLicenseVerificationRequest(license)
	verificationResp, err := s.callLicenseServer(*verificationReq)
	if err != nil {
		return nil, status.Errorf(codes.Unavailable, "failed to verify license: %v", err)
	}

	// Create response
	response := s.createLicenseVerificationResponse(verificationResp)

	// Cache the response if it's valid
	if response.Valid {
		s.lastValidResponse = response
		s.lastValidResponseTime = time.Now()
	}

	return response, nil
}

func (s *Server) createLicenseVerificationResponse(verificationResp *LicenseVerificationResponse) *protoLicense.VerifyLicenseResponse {
	return &protoLicense.VerifyLicenseResponse{
		Valid:           verificationResp.Valid,
		ExpiresAt:       timestamppb.New(verificationResp.ExpiresAt),
		MaxUsers:        int32(verificationResp.MaxUsers), // #nosec G115
		EnabledFeatures: verificationResp.EnabledFeatures,
		Message:         verificationResp.Message,
	}
}

func (s *Server) createLicenseVerificationRequest(license string) *LicenseVerificationRequest {
	if s.lastValidRequest != nil && time.Since(s.lastValidRequestTime) < cachedRequestDuration {
		return s.lastValidRequest
	}
	if s.lastValidRequest == nil {
		s.lastValidRequest = &LicenseVerificationRequest{}
	}
	s.lastValidRequest.License = license
	if kubeVersion := s.dataCollector.GetKubeVersion(); kubeVersion != "" {
		s.lastValidRequest.KubeVersion = kubeVersion
	}
	if installationID := s.dataCollector.GetInstallationID(); installationID != "" {
		s.lastValidRequest.InstallationID = installationID
	}
	if orgMembersCount := s.dataCollector.GetOrgMembersCount(); orgMembersCount > 0 {
		s.lastValidRequest.OrgMembersCount = orgMembersCount
	}
	if projectsCount := s.dataCollector.GetProjectsCount(); projectsCount > 0 {
		s.lastValidRequest.ProjectsCount = projectsCount
	}
	if appVersion := s.dataCollector.GetAppVersion(); appVersion != "" {
		s.lastValidRequest.AppVersion = appVersion
	}
	s.lastValidRequestTime = time.Now()
	return s.lastValidRequest
}

func (s *Server) callLicenseServer(req LicenseVerificationRequest) (*LicenseVerificationResponse, error) {
	return s.licenseClient.VerifyLicense(req)
}

type appDataCollector struct{}

func (d *appDataCollector) GetKubeVersion() string {
	kubernetesClient := kubernetes.NewClient()
	return kubernetesClient.GetKubeVersion()
}

func (d *appDataCollector) GetInstallationID() string {
	return clients.NewInstanceConfigClient().GetInstallationID()
}

func (d *appDataCollector) GetOrgMembersCount() int {
	conn, err := grpc.NewClient(config.UserEndpoint(), grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Fatalf("Failed to connect to user service: %v", err)
	}

	defer conn.Close()

	users, err := clients.NewUserClient(conn).SearchUsers(`%%`, maxUsers)
	if err != nil {
		log.Errorf("Failed to get users: %v", err)
		return 0
	}
	return len(users)
}

func (d *appDataCollector) GetProjectsCount() int {
	return 0
}

func (d *appDataCollector) GetAppVersion() string {
	return os.Getenv("CE_VERSION")
}
