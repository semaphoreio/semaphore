package main

import (
	"flag"
	"fmt"
	"net/http"
	"net/textproto"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/golang/glog"
	"github.com/grpc-ecosystem/grpc-gateway/v2/runtime"
	"golang.org/x/net/context"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/protobuf/encoding/protojson"

	artifacts "github.com/semaphoreio/semaphore/public-api-gateway/api/artifacts.v1"
	"github.com/semaphoreio/semaphore/public-api-gateway/api/clients"
	dashboards "github.com/semaphoreio/semaphore/public-api-gateway/api/dashboards.v1alpha"
	jobs "github.com/semaphoreio/semaphore/public-api-gateway/api/jobs.v1alpha"
	middleware "github.com/semaphoreio/semaphore/public-api-gateway/api/middleware"
	notifications "github.com/semaphoreio/semaphore/public-api-gateway/api/notifications.v1alpha"
	projectSecrets "github.com/semaphoreio/semaphore/public-api-gateway/api/project_secrets.v1"
	secrets "github.com/semaphoreio/semaphore/public-api-gateway/api/secrets.v1beta"
)

const MetadataPrefix = "grpcgateway-"

var (
	secretsV1BetaGRPCEndpoint        = os.Getenv("SECRETS_V1BETA_PUBLIC_GRPC_API_ENDPOINT")
	projectSecretsV1GRPCEndpoint     = os.Getenv("PROJECT_SECRETS_V1_PUBLIC_GRPC_API_ENDPOINT")
	dashboardsV1AlphaGRPCEndpoint    = os.Getenv("DASHBOARDS_V1ALPHA_PUBLIC_GRPC_API_ENDPOINT")
	jobsV1AlphaGRPCEndpoint          = os.Getenv("JOBS_V1ALPHA_PUBLIC_GRPC_API_ENDPOINT")
	notificationsV1AlphaGRPCEndpoint = os.Getenv("NOTIFICATIONS_V1ALPHA_PUBLIC_GRPC_API_ENDPOINT")
	artifactsV1GRPCEndpoint          = os.Getenv("ARTIFACTS_V1_PUBLIC_GRPC_API_ENDPOINT")

	defaultMaxReceiveMsgSize = 15 * 1024 * 1024 // 15MB
)

func headerMatcher(headerName string) (mdName string, ok bool) {
	headerName = textproto.CanonicalMIMEHeaderKey(headerName)
	if isPermanentHTTPHeader(headerName) {
		return MetadataPrefix + headerName, true
	} else if strings.HasPrefix(headerName, "X-") {
		return headerName, true
	}
	return "", false
}

func getMaxReceiveMessageSize() int {
	maxReceiveMsgSizeStr := os.Getenv("MAX_RECEIVE_MSG_SIZE")
	maxReceiveMsgSize, err := strconv.Atoi(maxReceiveMsgSizeStr)
	if err != nil {
		return defaultMaxReceiveMsgSize
	}
	return maxReceiveMsgSize
}

func run() error {
	ctx := context.Background()
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()

	var err error

	auditClient, err := clients.NewAuditClient(os.Getenv("AMQP_URL"))
	if err != nil {
		return fmt.Errorf("failed to initialize audit client: %v", err)
	}

	mux := runtime.NewServeMux(
		runtime.WithMiddlewares(middleware.AuditMiddleware(auditClient)),
		runtime.WithIncomingHeaderMatcher(headerMatcher),
		runtime.WithMarshalerOption(runtime.MIMEWildcard, &runtime.HTTPBodyMarshaler{
			Marshaler: &runtime.JSONPb{
				MarshalOptions: protojson.MarshalOptions{
					UseProtoNames:   true,
					EmitUnpopulated: true,
				},
				UnmarshalOptions: protojson.UnmarshalOptions{
					DiscardUnknown: true,
				},
			},
		}))

	// Set the load balancing policy to round robin
	serviceConfig := `{
		"loadBalancingPolicy": "round_robin"
	}`

	opts := []grpc.DialOption{
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithDefaultServiceConfig(serviceConfig),
		grpc.WithDefaultCallOptions(grpc.MaxCallRecvMsgSize(getMaxReceiveMessageSize())),
	}

	glog.Infof("Connecting Secrets V1Beta HTTP endpoint to '%s' GRPC API endpoint", secretsV1BetaGRPCEndpoint)
	err = secrets.RegisterSecretsApiHandlerFromEndpoint(ctx, mux, "dns:///"+secretsV1BetaGRPCEndpoint, opts)

	if err != nil {
		return err
	}

	glog.Infof("Connecting Project Secrets V1 HTTP endpoint to '%s' GRPC API endpoint", projectSecretsV1GRPCEndpoint)
	err = projectSecrets.RegisterProjectSecretsApiHandlerFromEndpoint(ctx, mux, "dns:///"+projectSecretsV1GRPCEndpoint, opts)

	if err != nil {
		return err
	}

	glog.Infof("Connecting Dashboards V1Alpha HTTP endpoint to '%s' GRPC API endpoint", dashboardsV1AlphaGRPCEndpoint)
	err = dashboards.RegisterDashboardsApiHandlerFromEndpoint(ctx, mux, "dns:///"+dashboardsV1AlphaGRPCEndpoint, opts)

	if err != nil {
		return err
	}

	glog.Infof("Connecting Jobs V1Alpha HTTP endpoint to '%s' GRPC API endpoint", jobsV1AlphaGRPCEndpoint)
	err = jobs.RegisterJobsApiHandlerFromEndpoint(ctx, mux, "dns:///"+jobsV1AlphaGRPCEndpoint, opts)

	if err != nil {
		return err
	}

	glog.Infof("Connecting Notifications V1Alpha HTTP endpoint to '%s' GRPC API endpoint", notificationsV1AlphaGRPCEndpoint)
	err = notifications.RegisterNotificationsApiHandlerFromEndpoint(ctx, mux, "dns:///"+notificationsV1AlphaGRPCEndpoint, opts)

	if err != nil {
		return err
	}

	glog.Infof("Connecting Artifacts V1 HTTP endpoint to '%s' GRPC API endpoint", artifactsV1GRPCEndpoint)
	err = artifacts.RegisterArtifactsServiceHandlerFromEndpoint(ctx, mux, "dns:///"+artifactsV1GRPCEndpoint, opts)

	if err != nil {
		return err
	}

	server := &http.Server{
		Addr:              ":8080",
		ReadHeaderTimeout: 10 * time.Second,
		WriteTimeout:      10 * time.Second,
		Handler:           mux,
	}

	return server.ListenAndServe()
}

func isPermanentHTTPHeader(hdr string) bool {
	switch hdr {
	case
		"Accept",
		"Accept-Charset",
		"Accept-Language",
		"Accept-Ranges",
		"Authorization",
		"Cache-Control",
		"Content-Type",
		"Cookie",
		"Date",
		"Expect",
		"From",
		"Host",
		"If-Match",
		"If-Modified-Since",
		"If-None-Match",
		"If-Schedule-Tag-Match",
		"If-Unmodified-Since",
		"Max-Forwards",
		"Origin",
		"Pragma",
		"Referer",
		"User-Agent",
		"Via",
		"Warning":
		return true
	}
	return false
}

func main() {
	flag.Parse()
	if err := flag.Lookup("logtostderr").Value.Set("true"); err != nil {
		glog.Fatal(err)
	}

	defer glog.Flush()

	if err := run(); err != nil {
		glog.Fatal(err)
	}
}
