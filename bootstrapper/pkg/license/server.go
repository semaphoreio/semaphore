package license

import (
	"context"
	"os"

	license "github.com/semaphoreio/semaphore/bootstrapper/pkg/protos/license"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type Server struct {
	license.UnimplementedLicenseServiceServer
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
	license.RegisterLicenseServiceServer(s, server)
}

func (s *Server) VerifyLicense(ctx context.Context, req *license.VerifyLicenseRequest) (*license.VerifyLicenseResponse, error) {
	// Read license from file
	licenseBytes, err := os.ReadFile(s.licenseFile)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to read license file: %v", err)
	}
	licenseJWT := string(licenseBytes)

	if licenseJWT == "" {
		return nil, status.Error(codes.NotFound, "license not found")
	}

	// Create verification request
	verificationReq := LicenseVerificationRequest{
		LicenseJWT:  licenseJWT,
		Hostname:    req.Hostname,
		IPAddress:   req.IpAddress,
		Environment: req.Environment,
		Version:     req.Version,
	}

	// Call license server
	resp, err := s.callLicenseServer(verificationReq)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to verify license: %v", err)
	}

	return &license.VerifyLicenseResponse{
		Valid:           resp.Valid,
		ExpiresAt:       resp.ExpiresAt.Unix(),
		MaxUsers:        int32(resp.MaxUsers),
		EnabledFeatures: resp.EnabledFeatures,
		Message:         resp.Message,
	}, nil
}

func (s *Server) callLicenseServer(req LicenseVerificationRequest) (*LicenseVerificationResponse, error) {
	return s.licenseClient.VerifyLicense(req)
}
