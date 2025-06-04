package license

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"testing"
	"time"

	license "github.com/semaphoreio/semaphore/bootstrapper/pkg/protos/license"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/test/bufconn"
)

const bufSize = 1024 * 1024

var lis *bufconn.Listener

func bufDialer(context.Context, string) (net.Conn, error) {
	return lis.Dial()
}

type mockTransport struct {
	responseFunc func(*http.Request) (*http.Response, error)
}

func (m *mockTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	return m.responseFunc(req)
}

func createMockServer(t *testing.T, mockClient *http.Client, licenseFile string) (license.LicenseServiceClient, func()) {
	mockServerURL := "http://mock-license-server"
	lis = bufconn.Listen(bufSize)
	s := grpc.NewServer()
	licenseServer := NewServer(mockServerURL, licenseFile)
	if mockClient != nil {
		licenseServer.licenseClient = NewClient(mockServerURL, mockClient)
	}
	RegisterServer(s, licenseServer)

	go func() {
		if err := s.Serve(lis); err != nil {
			t.Errorf("Server exited with error: %v", err)
		}
	}()

	// Create a client connection
	ctx := context.Background()
	conn, err := grpc.DialContext(ctx, "bufnet",
		grpc.WithContextDialer(bufDialer),
		grpc.WithTransportCredentials(insecure.NewCredentials()),
	)
	require.NoError(t, err)

	client := license.NewLicenseServiceClient(conn)
	return client, func() {
		conn.Close()
		s.Stop()
	}
}

func TestServer_VerifyLicense(t *testing.T) {
	// Create a temporary license file
	tmpDir := t.TempDir()
	licenseFile := filepath.Join(tmpDir, "license.jwt")
	err := os.WriteFile(licenseFile, []byte("test-license-jwt"), 0644)
	require.NoError(t, err)

	tests := []struct {
		name           string
		setupFunc      func() (license.LicenseServiceClient, func())
		req            *license.VerifyLicenseRequest
		wantErr        bool
		wantErrMessage string
	}{
		{
			name: "valid request",
			setupFunc: func() (license.LicenseServiceClient, func()) {
				// Create mock HTTP client for valid response
				mockTransport := &mockTransport{
					responseFunc: func(req *http.Request) (*http.Response, error) {
						response := &LicenseVerificationResponse{
							Valid:           true,
							ExpiresAt:       time.Now().Add(24 * time.Hour),
							MaxUsers:        10,
							EnabledFeatures: []string{"feature1", "feature2"},
							Message:         "License is valid",
						}
						respBytes, err := json.Marshal(response)
						if err != nil {
							return nil, err
						}
						return &http.Response{
							StatusCode: http.StatusOK,
							Body:       io.NopCloser(bytes.NewReader(respBytes)),
						}, nil
					},
				}
				mockClient := &http.Client{Transport: mockTransport}
				return createMockServer(t, mockClient, licenseFile)
			},
			req:     &license.VerifyLicenseRequest{},
			wantErr: false,
		},
		{
			name: "missing license file",
			setupFunc: func() (license.LicenseServiceClient, func()) {
				return createMockServer(t, nil, "/nonexistent/license.jwt")
			},
			req:            &license.VerifyLicenseRequest{},
			wantErr:        true,
			wantErrMessage: "failed to read license file",
		},
		{
			name: "invalid license response",
			setupFunc: func() (license.LicenseServiceClient, func()) {
				// Create mock HTTP client for invalid response
				mockTransport := &mockTransport{
					responseFunc: func(req *http.Request) (*http.Response, error) {
						response := &LicenseVerificationResponse{
							Valid:   false,
							Message: "License is invalid",
						}
						respBytes, err := json.Marshal(response)
						if err != nil {
							return nil, err
						}
						return &http.Response{
							StatusCode: http.StatusOK,
							Body:       io.NopCloser(bytes.NewReader(respBytes)),
						}, nil
					},
				}
				mockClient := &http.Client{Transport: mockTransport}
				return createMockServer(t, mockClient, licenseFile)
			},
			req:     &license.VerifyLicenseRequest{},
			wantErr: false,
		},
		{
			name: "license server error",
			setupFunc: func() (license.LicenseServiceClient, func()) {
				// Create mock HTTP client that returns error
				mockTransport := &mockTransport{
					responseFunc: func(req *http.Request) (*http.Response, error) {
						return &http.Response{
							StatusCode: http.StatusInternalServerError,
							Body:       io.NopCloser(bytes.NewReader([]byte(`{"error": "internal server error"}`))),
						}, nil
					},
				}
				mockClient := &http.Client{Transport: mockTransport}
				return createMockServer(t, mockClient, licenseFile)
			},
			req:            &license.VerifyLicenseRequest{},
			wantErr:        true,
			wantErrMessage: "unexpected status code: 500",
		},
	}

	ctx := context.Background()

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			client, cleanup := tt.setupFunc()
			defer cleanup()

			resp, err := client.VerifyLicense(ctx, tt.req)
			if tt.wantErr {
				assert.Error(t, err)
				if tt.wantErrMessage != "" {
					assert.Contains(t, err.Error(), tt.wantErrMessage)
				}
				return
			}

			assert.NoError(t, err)
			assert.NotNil(t, resp)

			// For successful responses, verify the response fields
			if resp.Valid {
				assert.Equal(t, int32(10), resp.MaxUsers)
				assert.Equal(t, []string{"feature1", "feature2"}, resp.EnabledFeatures)
				assert.Equal(t, "License is valid", resp.Message)
			} else {
				assert.Equal(t, "License is invalid", resp.Message)
			}
		})
	}
}
