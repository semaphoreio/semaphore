package privateserver

import (
	"context"
	"fmt"
	"net"
	"os"
	"strconv"
	"time"

	recovery "github.com/grpc-ecosystem/go-grpc-middleware/v2/interceptors/recovery"
	uuid "github.com/satori/go.uuid"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/api/descriptors/artifacthub"
	privateapi "github.com/semaphoreio/semaphore/artifacthub/pkg/api/private"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/jwt"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/models"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/storage"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/util/log"
	"go.uber.org/zap"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
)

const (
	defaultMaxReceiveMsgSize = 15 * 1024 * 1024 // 15MB
	maxTokenDuration         = 24 * time.Hour
)

// Server is a GRPC server that will handle incoming calls.
type Server struct {
	Port            int
	recoveryHandler recovery.RecoveryHandlerFunc
	StorageClient   storage.Client
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

// HealthCheck returns an error in case of something is in a wrong state.
// At the same time, returning anything says that the grpc server is up and running too.
func (s *Server) HealthCheck(ctx context.Context,
	request *artifacthub.HealthCheckRequest) (*artifacthub.HealthCheckResponse, error) {
	log.Info("[HealthCheck] Received", zap.Reflect("request", request))

	response := &artifacthub.HealthCheckResponse{}
	ok := models.Check()
	if !ok {
		return nil, log.ErrorCode(codes.NotFound, "database doesn't seem to work", nil)
	}

	log.Debug("[HealthCheck] Sending response")
	return response, nil
}

func serializeArtifactModelToAPIModel(src *models.Artifact) *artifacthub.Artifact {
	return &artifacthub.Artifact{
		Id:         src.ID.String(),
		BucketName: src.BucketName,
	}
}

func (s *Server) Create(ctx context.Context,
	request *artifacthub.CreateRequest) (*artifacthub.CreateResponse, error) {
	log.Info("[Create] Received", zap.Reflect("request", request))

	a, err := privateapi.CreateArtifact(ctx, s.StorageClient, request.RequestToken)
	if err != nil {
		return nil, err
	}

	response := &artifacthub.CreateResponse{Artifact: serializeArtifactModelToAPIModel(a)}

	log.Info("[Create] Sending", zap.Reflect("response", response))
	return response, nil
}

func (s *Server) Describe(ctx context.Context, request *artifacthub.DescribeRequest) (*artifacthub.DescribeResponse, error) {
	log.Info("[Describe] Received", zap.Reflect("request", request))

	artifactID, err := uuid.FromString(request.ArtifactId)
	if err != nil {
		return nil, log.ErrorCode(codes.FailedPrecondition, "artifact bucket ID is malformed", nil)
	}

	a, err := models.FindArtifactByID(artifactID.String())
	if err != nil {
		return nil, err
	}

	response := &artifacthub.DescribeResponse{Artifact: serializeArtifactModelToAPIModel(a)}

	if request.IncludeRetentionPolicy {
		policy, err := models.FindRetentionPolicyOrReturnEmpty(artifactID)
		if err != nil {
			return nil, log.ErrorCode(codes.Internal, "failed to describe artifact", nil)
		}

		marshaledPolicy, err := marshalRetentionPolicyModelToAPIModel(policy)
		if err != nil {
			return nil, log.ErrorCode(codes.Internal, "failed to describe artifact", nil)
		}

		response.RetentionPolicy = marshaledPolicy
	}

	log.Debug("[Describe] Sending", zap.Reflect("response", response))
	return response, nil
}

func (s *Server) Destroy(ctx context.Context,
	request *artifacthub.DestroyRequest) (*artifacthub.DestroyResponse, error) {
	log.Info("[Destroy] Received", zap.Reflect("request", request))

	response := &artifacthub.DestroyResponse{}
	err := privateapi.DestroyArtifact(ctx, s.StorageClient, request.ArtifactId)
	if err != nil {
		log.Error("[Destroy] Failed to destroy", zap.Reflect("request", request), zap.Error(err))
		return nil, err
	}

	return response, nil
}

// ListPath lists contents of a directory in the given Artifact's bucket by it's id.
func (s *Server) ListPath(ctx context.Context,
	request *artifacthub.ListPathRequest) (*artifacthub.ListPathResponse, error) {
	log.Debug("[ListPath] Received", zap.Reflect("request", request))

	response := &artifacthub.ListPathResponse{}
	is, err := privateapi.ListArtifactPath(ctx, s.StorageClient, request.ArtifactId, request.Path, !request.UnwrapDirectories)
	if err != nil {
		return nil, err
	}

	response.Items = is
	log.Debug("[ListPath] Sending", zap.Reflect("response", response))
	return response, nil
}

// DeletePath deletes an object or directory in the given Artifact's bucket given by its ID.
func (s *Server) DeletePath(ctx context.Context,
	request *artifacthub.DeletePathRequest) (*artifacthub.DeletePathResponse, error) {
	log.Debug("[DeletePath] Received", zap.Reflect("request", request))

	response := &artifacthub.DeletePathResponse{}
	err := privateapi.DeleteArtifactPath(ctx, s.StorageClient, request.ArtifactId, request.Path)
	if err != nil {
		return nil, err
	}

	log.Debug("[DeletePath] Sending response")
	return response, nil
}

// Cleanup deletes all expired paths for all Buckets.
func (s *Server) Cleanup(ctx context.Context,
	request *artifacthub.CleanupRequest) (*artifacthub.CleanupResponse, error) {
	return nil, log.ErrorCode(codes.FailedPrecondition, "Not Supported", nil)
}

// GetSignedURL returns a signed URL for a given object path.
func (s *Server) GetSignedURL(ctx context.Context,
	request *artifacthub.GetSignedURLRequest) (*artifacthub.GetSignedURLResponse, error) {
	log.Debug("[GetSignedURL] Received", zap.Reflect("request", request))

	response := &artifacthub.GetSignedURLResponse{}
	url, err := privateapi.GetSignedURL(ctx, s.StorageClient, request.ArtifactId, request.Path, request.Method)
	if err != nil {
		return nil, err
	}
	response.Url = url

	log.Debug("[GetSignedURL] Sending response")
	return response, nil
}

// ListBuckets returns (artifact store ID, bucket name) map for the list of artifact store IDs.
func (s *Server) ListBuckets(ctx context.Context,
	request *artifacthub.ListBucketsRequest) (*artifacthub.ListBucketsResponse, error) {
	log.Info("[ListBuckets] Received", zap.Reflect("request", request))

	response := &artifacthub.ListBucketsResponse{}
	BucketNamesForIDs, err := models.ListBucketsForIDs(request.Ids)
	if err != nil {
		return nil, err
	}
	response.BucketNamesForIds = BucketNamesForIDs

	log.Debug("[ListBuckets] Sending response")
	return response, nil
}

// CountArtifacts returns the recursive count of artifacts for a given category
// (project/workflow/job) with its ID (eg. jobID).
func (s *Server) CountArtifacts(ctx context.Context, request *artifacthub.CountArtifactsRequest,
) (*artifacthub.CountArtifactsResponse, error) {
	log.Info("[CountArtifacts] Received", zap.Reflect("request", request))

	response := &artifacthub.CountArtifactsResponse{}
	count, err := privateapi.CountCategoryPath(ctx, s.StorageClient, request.Category, request.CategoryId,
		request.ArtifactId)
	if err != nil {
		return nil, err
	}
	response.ArtifactCount = int32(count)

	log.Debug("[CountArtifacts] Sending response", zap.Reflect("response", response))
	return response, nil
}

func (s *Server) CountBuckets(
	ctx context.Context,
	request *artifacthub.CountBucketsRequest,
) (*artifacthub.CountBucketsResponse, error) {
	log.Info("[CountBuckets] Received", zap.Reflect("request", request))

	response := &artifacthub.CountBucketsResponse{}
	count, err := models.BucketCount()
	if err != nil {
		return nil, err
	}
	response.BucketCount = int32(count)

	log.Debug("[CountBuckets] Sending response", zap.Reflect("response", response))
	return response, nil
}

// UpdateCORS updates CORS property on the given bucket with the currently valid one.
func (s *Server) UpdateCORS(
	ctx context.Context,
	request *artifacthub.UpdateCORSRequest,
) (*artifacthub.UpdateCORSResponse, error) {
	log.Info("[UpdateCORS] Received", zap.Reflect("request", request))

	response := &artifacthub.UpdateCORSResponse{}
	bucketName := request.BucketName
	var err error

	if len(bucketName) == 0 {
		if bucketName, err = models.FindNextBucket(bucketName); err != nil {
			return nil, err
		}
		if len(bucketName) == 0 {
			return nil, log.ErrorCode(codes.NotFound, "no bucket found in database: ", nil)
		}
		log.Info("[UpdateCORS] updating first bucket", zap.String("bucketName", bucketName))
	}

	nextBucketName, err := models.FindNextBucket(bucketName)
	if err == nil {
		response.NextBucketName = nextBucketName
	}

	bucket := s.StorageClient.GetBucket(storage.BucketOptions{Name: bucketName})
	if err = bucket.SetCORS(ctx); err != nil {
		return response, err
	}

	log.Debug("[UpdateCORS] Sending response", zap.Reflect("response", response))
	return response, nil
}

func (s *Server) UpdateRetentionPolicy(ctx context.Context, request *artifacthub.UpdateRetentionPolicyRequest) (*artifacthub.UpdateRetentionPolicyResponse, error) {
	log.Info("[UpdateRetentionPolicy] Received", zap.Reflect("request", request))

	artifactBucketID, err := uuid.FromString(request.ArtifactId)
	if err != nil {
		return nil, log.ErrorCode(codes.FailedPrecondition, "artifact bucket ID is malformed", nil)
	}

	project := marshalRetentionPolicyRuleToModel(request.RetentionPolicy.ProjectLevelRetentionPolicies)
	workflow := marshalRetentionPolicyRuleToModel(request.RetentionPolicy.WorkflowLevelRetentionPolicies)
	job := marshalRetentionPolicyRuleToModel(request.RetentionPolicy.JobLevelRetentionPolicies)

	policy, err := models.UpdateRetentionPolicy(artifactBucketID, project, workflow, job)
	if err != nil {
		return nil, marshalRetentionPolicyUpdateError(err)
	}

	marshaledPolicy, err := marshalRetentionPolicyModelToAPIModel(policy)
	if err != nil {
		return nil, marshalRetentionPolicyUpdateError(err)
	}

	response := &artifacthub.UpdateRetentionPolicyResponse{
		RetentionPolicy: marshaledPolicy,
	}

	return response, nil
}

func (s *Server) GenerateToken(ctx context.Context, req *artifacthub.GenerateTokenRequest) (*artifacthub.GenerateTokenResponse, error) {
	log.Info("[GenerateToken] Received", zap.Reflect("request", req))

	if err := s.validateUUIDs([]string{req.ArtifactId, req.JobId, req.ProjectId}); err != nil {
		return nil, log.ErrorCode(codes.InvalidArgument, "invalid request", nil)
	}

	// Workflow IDs can be empty for project debug jobs.
	// A token with an empty workflow ID clause will not
	// have any workflow-level restrictions.
	if req.WorkflowId != "" {
		if err := s.validateUUIDs([]string{req.WorkflowId}); err != nil {
			return nil, log.ErrorCode(codes.InvalidArgument, "invalid request", nil)
		}
	}

	duration := time.Duration(req.Duration) * time.Second
	if duration == 0 {
		duration = 24 * time.Hour
	}

	if duration > maxTokenDuration {
		return nil, log.ErrorCode(codes.InvalidArgument, "invalid duration", nil)
	}

	claims := jwt.Claims{
		ArtifactID: req.ArtifactId,
		Job:        req.JobId,
		Workflow:   req.WorkflowId,
		Project:    req.ProjectId,
	}

	token, err := jwt.GenerateToken(s.jwtSecret, claims, duration)
	if err != nil {
		return nil, err
	}

	return &artifacthub.GenerateTokenResponse{Token: token}, nil
}

func (s *Server) validateUUIDs(values []string) error {
	for _, v := range values {
		_, err := uuid.FromString(v)
		if err != nil {
			return err
		}
	}

	return nil
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
		grpc.MaxRecvMsgSize(getMaxReceiveMessageSize()),
	)

	artifacthub.RegisterArtifactServiceServer(grpcServer, s)

	log.Info("Starting internal GRPC...\n", zap.Int("port", s.Port))
	return grpcServer.Serve(lis)
}

func getMaxReceiveMessageSize() int {
	maxReceiveMsgSizeStr := os.Getenv("MAX_PRIVATE_RECEIVE_MSG_SIZE")
	maxReceiveMsgSize, err := strconv.Atoi(maxReceiveMsgSizeStr)
	if err != nil {
		return defaultMaxReceiveMsgSize
	}
	return maxReceiveMsgSize
}
