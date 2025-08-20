package publicserver

import (
	"context"
	"fmt"
	"net"
	"os"
	"regexp"
	"strconv"
	"time"

	gojwt "github.com/golang-jwt/jwt/v5"
	recovery "github.com/grpc-ecosystem/go-grpc-middleware/v2/interceptors/recovery"
	"github.com/renderedtext/go-watchman"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/api/descriptors/artifacts"
	publicapi "github.com/semaphoreio/semaphore/artifacthub/pkg/api/public"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/jwt"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/models"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/storage"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/util/log"
	"go.uber.org/zap"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/keepalive"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

var (
	ResourceTypeProjects  = "projects"
	ResourceTypeWorkflows = "workflows"
	ResourceTypeJobs      = "jobs"
	ResourceTypes         = []string{ResourceTypeProjects, ResourceTypeWorkflows, ResourceTypeJobs}

	pathRegex = regexp.MustCompile(`artifacts\/(projects|workflows|jobs)\/([a-z0-9\-]{36})\/*`)
)

const (
	defaultMaxReceiveMsgSize = 15 * 1024 * 1024 // 15MB
)

// Server is a GRPC server that will handle incoming calls.
type Server struct {
	Port            int
	StorageClient   storage.Client
	recoveryHandler recovery.RecoveryHandlerFunc
	jwtSecret       string
}

// NewServer creates a new GRPC server with the given port.
func NewServer(port int, client storage.Client, jwtSecret string) *Server {
	return &Server{
		Port:          port,
		StorageClient: client,
		jwtSecret:     jwtSecret,
	}
}

func getAuthTokenFromContext(ctx context.Context) (string, error) {
	headers, ok := metadata.FromIncomingContext(ctx)
	if !ok {
		return "", log.ErrorCode(codes.Unauthenticated, "failed to get headers from grpc context", nil)
	}

	auth := headers["authorization"]
	if len(auth) == 0 || len(auth[0]) == 0 {
		auth = headers["grpcgateway-authorization"]
	}

	if len(auth) == 0 || len(auth[0]) == 0 {
		return "", log.ErrorCode(codes.Unauthenticated, "public grpc auth header empty", nil)
	}

	return auth[0], nil
}

// GenerateSignedURLs generates signed URLs for uploading to and downloading from the
// artifact storage, and deleting as well.
func (s *Server) GenerateSignedURLs(ctx context.Context,
	q *artifacts.GenerateSignedURLsRequest) (*artifacts.GenerateSignedURLsResponse, error) {
	response := &artifacts.GenerateSignedURLsResponse{}
	token, err := getAuthTokenFromContext(ctx)
	if err != nil {
		return nil, err
	}

	_ = watchman.Submit("signed.urls.count", len(q.Paths))

	// If there are no paths to use, just return
	if len(q.Paths) == 0 {
		return response, nil
	}

	artifact, claims, err := s.authenticateAndGetClaims(token, q.Paths)
	if err != nil {
		log.Error("Error authenticating request", zap.Error(err))
		return nil, err
	}

	log.Info("[GenerateSignedURLs] Authenticated request",
		zap.String("type", q.Type.String()),
		zap.Int("paths_count", len(q.Paths)),
		zap.Strings("paths", q.Paths),
		zap.String("artifact", claims.ArtifactID),
		zap.String("project", claims.Project),
		zap.String("job", claims.Job),
		zap.String("workflow", claims.Workflow),
	)

	var us []*artifacts.SignedURL
	switch q.Type {
	case artifacts.GenerateSignedURLsRequest_PUSH:
		us, err = publicapi.GenerateSignedURLPush(ctx, s.StorageClient, artifact, q.Paths, false)
	case artifacts.GenerateSignedURLsRequest_PUSHFORCE:
		us, err = publicapi.GenerateSignedURLPush(ctx, s.StorageClient, artifact, q.Paths, true)
	case artifacts.GenerateSignedURLsRequest_PULL:
		us, err = publicapi.GenerateSignedURLPull(ctx, s.StorageClient, artifact, q.Paths[0])
	case artifacts.GenerateSignedURLsRequest_YANK:
		us, err = publicapi.GenerateSignedURLYank(ctx, s.StorageClient, artifact, q.Paths[0])
	}

	log.Debug("", zap.Reflect("signed urls", us), zap.Error(err))
	if err != nil {
		switch err {
		case publicapi.ErrArtifactNotFound:
			return nil, status.Error(codes.NotFound, err.Error())
		default:
			log.Error("[GenerateSignedURLs] Unknown error", zap.Error(err))
			return nil, err
		}
	}

	response.URLs = us
	log.Debug("[GenerateSignedURLs] Sending", zap.Reflect("response", response))
	return response, nil
}

// Serve runs GRPC Server, and waits for incoming calls.
func (s *Server) Serve() {
	lis, err := net.Listen("tcp", fmt.Sprintf("0.0.0.0:%d", s.Port))

	if err != nil {
		panic(log.ErrorCode(codes.Unavailable, "failed to listen", err))
	}

	err = s.serveWithListener(lis)

	if err != nil {
		panic(log.ErrorCode(codes.Unavailable, "failed to serve", err))
	}
}

func (s *Server) serveWithListener(lis net.Listener) error {
	opts := []recovery.Option{
		recovery.WithRecoveryHandler(s.recoveryHandler),
	}

	grpcServer := grpc.NewServer(
		grpc.ChainUnaryInterceptor(
			recovery.UnaryServerInterceptor(opts...),
		),
		grpc.ChainStreamInterceptor(
			recovery.StreamServerInterceptor(opts...),
		),
		grpc.KeepaliveParams(keepalive.ServerParameters{
			MaxConnectionAge:      time.Minute,
			MaxConnectionAgeGrace: 30 * time.Second,
		}),
		grpc.MaxRecvMsgSize(getMaxReceiveMessageSize()),
	)

	artifacts.RegisterArtifactsServiceServer(grpcServer, s)

	log.Info("Starting public GRPC...", zap.Int("port", s.Port))
	return grpcServer.Serve(lis)

}

func getMaxReceiveMessageSize() int {
	maxReceiveMsgSizeStr := os.Getenv("MAX_PUBLIC_RECEIVE_MSG_SIZE")
	maxReceiveMsgSize, err := strconv.Atoi(maxReceiveMsgSizeStr)
	if err != nil {
		return defaultMaxReceiveMsgSize
	}
	return maxReceiveMsgSize
}

func (s *Server) authenticateAndGetClaims(token string, paths []string) (*models.Artifact, *jwt.Claims, error) {
	resourceType, resourceID, err := s.findAndValidateResource(paths)
	if err != nil {
		return nil, nil, err
	}

	claims, err := s.validateJWT(resourceType, resourceID, token)
	if err != nil {
		return nil, nil, status.Error(codes.PermissionDenied, err.Error())
	}

	artifacts, err := models.FindArtifactByID(claims.ArtifactID)
	if err != nil {
		return nil, nil, err
	}

	return artifacts, claims, nil
}

func (s *Server) validateJWT(resourceType, resourceID, token string) (*jwt.Claims, error) {
	switch resourceType {
	case ResourceTypeJobs:
		return jwt.ValidateToken(token, s.jwtSecret, func(claims gojwt.MapClaims) error {
			if claims["job"] != resourceID {
				return fmt.Errorf("invalid claim: job")
			}

			return nil
		})

	case ResourceTypeProjects:
		return jwt.ValidateToken(token, s.jwtSecret, func(claims gojwt.MapClaims) error {
			if claims["project"] != resourceID {
				return fmt.Errorf("invalid claim: project")
			}

			return nil
		})

	case ResourceTypeWorkflows:
		return jwt.ValidateToken(token, s.jwtSecret, func(claims gojwt.MapClaims) error {
			if claims["workflow"] != resourceID {
				return fmt.Errorf("invalid claim: workflow")
			}

			return nil
		})

	default:
		return nil, fmt.Errorf("unrecognized resource type '%s'", resourceType)
	}
}

func (s *Server) findAndValidateResource(paths []string) (string, string, error) {
	matches := pathRegex.FindStringSubmatch(paths[0])
	if matches == nil || len(matches) < 3 {
		return "", "", status.Errorf(codes.InvalidArgument, "invalid path %s", paths[0])
	}

	resourceType := matches[1]
	resourceID := matches[2]

	// All the paths must have the same resource type and ID
	for _, p := range paths[1:] {
		matches := pathRegex.FindStringSubmatch(p)
		if matches == nil || len(matches) < 3 {
			return "", "", status.Errorf(codes.InvalidArgument, "invalid path %s", p)
		}

		if matches[1] != resourceType || matches[2] != resourceID {
			return "", "", status.Errorf(codes.InvalidArgument, "invalid resource in path %s", p)
		}
	}

	return resourceType, resourceID, nil
}
