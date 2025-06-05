package cmd

import (
	"fmt"
	"log"
	"net"
	"os"
	"strconv"

	license "github.com/semaphoreio/semaphore/bootstrapper/pkg/license"
	"github.com/spf13/cobra"
	"google.golang.org/grpc"
)

var (
	grpcPort         int
	licenseServerURL string
	licenseFile      string
	enableGRPC       bool
)

const (
	defaultGRPCPort    = 50051
	defaultLicenseFile = "/app/config/app.license"
)

var serveCmd = &cobra.Command{
	Use:   "serve",
	Short: "Start the license verification gRPC server",
	PreRun: func(cmd *cobra.Command, args []string) {
		// Check environment variables
		if envPort := os.Getenv("BOOTSTRAPPER_GRPC_PORT"); envPort != "" {
			if port, err := strconv.Atoi(envPort); err == nil {
				grpcPort = port
			} else {
				log.Fatalf("Invalid gRPC port: %s", envPort)
			}
		} else {
			grpcPort = defaultGRPCPort
		}

		licenseServerURL = os.Getenv("BOOTSTRAPPER_LICENSE_SERVER_URL")
		if envLicenseFile := os.Getenv("BOOTSTRAPPER_LICENSE_FILE"); envLicenseFile != "" {
			licenseFile = envLicenseFile
		} else {
			licenseFile = defaultLicenseFile
		}
		enableGRPC = os.Getenv("BOOTSTRAPPER_ENABLE_GRPC") == "true"
	},
	RunE: func(cmd *cobra.Command, args []string) error {
		if !enableGRPC {
			log.Println("gRPC server is disabled")
			return nil
		}
		// Create gRPC server
		grpcServer := grpc.NewServer()

		// Create and register license server
		licenseServer := license.NewServer(licenseServerURL, licenseFile)
		license.RegisterServer(grpcServer, licenseServer)

		// Start listening
		lis, err := net.Listen("tcp", fmt.Sprintf(":%d", grpcPort))
		if err != nil {
			return fmt.Errorf("failed to listen: %v", err)
		}

		log.Printf("Starting gRPC server on port %d", grpcPort)
		if err := grpcServer.Serve(lis); err != nil {
			return fmt.Errorf("failed to serve: %v", err)
		}

		return nil
	},
}

func init() {
	RootCmd.AddCommand(serveCmd)
}
