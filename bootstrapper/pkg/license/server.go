package license

import (
	"context"
	"os"

	protoLicense "github.com/semaphoreio/semaphore/bootstrapper/pkg/protos/license"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"
)

type Server struct {
	protoLicense.UnimplementedLicenseServiceServer
	licenseClient *Client
	licenseFile   string
}

func NewServer(licenseServerURL, licenseFile string) *Server {
	return &Server{
		licenseClient: NewClient(licenseServerURL, nil),
		licenseFile:   licenseFile,
	}
}

func RegisterServer(s *grpc.Server, server *Server) {
	protoLicense.RegisterLicenseServiceServer(s, server)
}

func (s *Server) VerifyLicense(ctx context.Context, req *protoLicense.VerifyLicenseRequest) (*protoLicense.VerifyLicenseResponse, error) {
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
	verificationReq := LicenseVerificationRequest{
		License:         license,
		AppVersion:      "EE v1.2.0",
		InstallationID:  "test-installation-id",
		KubeVersion:     "v1.24.0",
		OrgMembersCount: 10,
		ProjectsCount:   5,
	}

	// Call license server
	verificationResp, err := s.callLicenseServer(verificationReq)
	if err != nil {
		return nil, status.Errorf(codes.Unavailable, "failed to verify license: %v", err)
	}
	resp := &protoLicense.VerifyLicenseResponse{
		Valid:           verificationResp.Valid,
		ExpiresAt:       timestamppb.New(verificationResp.ExpiresAt),
		MaxUsers:        int32(verificationResp.MaxUsers),
		EnabledFeatures: verificationResp.EnabledFeatures,
		Message:         verificationResp.Message,
	}
	return resp, nil
}

func (s *Server) callLicenseServer(req LicenseVerificationRequest) (*LicenseVerificationResponse, error) {
	return s.licenseClient.VerifyLicense(req)
}
