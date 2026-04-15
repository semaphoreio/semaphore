package privateserver

import (
	"context"
	"fmt"
	"net"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"

	gojwt "github.com/golang-jwt/jwt/v5"
	uuid "github.com/satori/go.uuid"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/api/descriptors/artifacthub"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/jwt"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/models"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/storage"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/grpc/test/bufconn"
	"gorm.io/gorm"
)

func Test__Create(t *testing.T) {
	storage.RunTestForAllBackends(t, func(backend string, client storage.Client) {
		models.PrepareDatabaseForTests()
		server := Server{StorageClient: client}

		t.Run(backend+" creates aritfact and bucket", func(t *testing.T) {
			request := &artifacthub.CreateRequest{RequestToken: "request-token-1"}
			response, err := server.Create(context.TODO(), request)
			assert.Nil(t, err)
			assert.NotEmpty(t, response.Artifact.Id)
			assert.NotEmpty(t, response.Artifact.BucketName)
			assert.Empty(t, response.Artifact.ArtifactToken)

			a, err := models.FindArtifactByID(response.Artifact.Id)
			assert.Nil(t, err)
			assert.Equal(t, a.ID.String(), response.Artifact.Id)
			assert.Equal(t, a.BucketName, response.Artifact.BucketName)
		})
	})
}

func Test__ListBuckets(t *testing.T) {
	storage.RunTestForAllBackends(t, func(backend string, client storage.Client) {
		models.PrepareDatabaseForTests()
		server := Server{StorageClient: client}

		t.Run(backend, func(t *testing.T) {
			first, err := server.Create(context.TODO(), &artifacthub.CreateRequest{RequestToken: "request-token-1"})
			assert.Nil(t, err)

			second, err := server.Create(context.TODO(), &artifacthub.CreateRequest{RequestToken: "request-token-2"})
			assert.Nil(t, err)

			third, err := server.Create(context.TODO(), &artifacthub.CreateRequest{RequestToken: "request-token-3"})
			assert.Nil(t, err)

			response, err := server.ListBuckets(context.TODO(), &artifacthub.ListBucketsRequest{
				Ids: []string{first.Artifact.Id, second.Artifact.Id, third.Artifact.Id},
			})

			assert.Nil(t, err)
			assert.Equal(t, map[string]string{
				first.Artifact.Id:  first.Artifact.BucketName,
				second.Artifact.Id: second.Artifact.BucketName,
				third.Artifact.Id:  third.Artifact.BucketName,
			}, response.BucketNamesForIds)

			// S3 uses the same bucket
			if backend == "s3" {
				assert.Equal(t, first.Artifact.BucketName, second.Artifact.BucketName)
				assert.Equal(t, first.Artifact.BucketName, third.Artifact.BucketName)
			} else {
				assert.NotEqual(t, first.Artifact.BucketName, second.Artifact.BucketName)
				assert.NotEqual(t, first.Artifact.BucketName, third.Artifact.BucketName)
			}
		})
	})
}

func Test__CountBuckets(t *testing.T) {
	storage.RunTestForAllBackends(t, func(backend string, client storage.Client) {
		models.PrepareDatabaseForTests()
		server := Server{StorageClient: client}

		t.Run(backend, func(t *testing.T) {
			_, err := server.Create(context.TODO(), &artifacthub.CreateRequest{RequestToken: "request-token-1"})
			assert.Nil(t, err)

			_, err = server.Create(context.TODO(), &artifacthub.CreateRequest{RequestToken: "request-token-2"})
			assert.Nil(t, err)

			_, err = server.Create(context.TODO(), &artifacthub.CreateRequest{RequestToken: "request-token-3"})
			assert.Nil(t, err)

			response, err := server.CountBuckets(context.TODO(), &artifacthub.CountBucketsRequest{})
			assert.Nil(t, err)

			if backend == "s3" {
				assert.Equal(t, int32(1), response.BucketCount)
			} else {
				assert.Equal(t, int32(3), response.BucketCount)
			}
		})
	})
}

func Test__CountArtifacts(t *testing.T) {
	storage.RunTestForAllBackends(t, func(backend string, client storage.Client) {
		models.PrepareDatabaseForTests()
		server := Server{StorageClient: client}

		idempotencyToken := "request-token-1"
		response, err := server.Create(context.TODO(), &artifacthub.CreateRequest{RequestToken: idempotencyToken})
		if !assert.Nil(t, err) {
			return
		}

		options := storage.BucketOptions{
			Name:       response.Artifact.BucketName,
			PathPrefix: idempotencyToken,
		}

		err = storage.SeedBucket(client.GetBucket(options), seedObjects())
		if !assert.Nil(t, err) {
			return
		}

		artifactId := response.Artifact.Id

		t.Run(backend+" returns artifacts for project", func(t *testing.T) {
			request := &artifacthub.CountArtifactsRequest{
				Category:   artifacthub.CountArtifactsRequest_PROJECT,
				CategoryId: "first",
				ArtifactId: artifactId,
			}

			response, err := server.CountArtifacts(context.TODO(), request)
			assert.Nil(t, err)
			assert.Equal(t, int32(3), response.ArtifactCount)

			request = &artifacthub.CountArtifactsRequest{
				Category:   artifacthub.CountArtifactsRequest_PROJECT,
				CategoryId: "second",
				ArtifactId: artifactId,
			}

			response, err = server.CountArtifacts(context.TODO(), request)
			assert.Nil(t, err)
			assert.Equal(t, int32(2), response.ArtifactCount)

			request = &artifacthub.CountArtifactsRequest{
				Category:   artifacthub.CountArtifactsRequest_PROJECT,
				CategoryId: "notfound",
				ArtifactId: artifactId,
			}

			response, err = server.CountArtifacts(context.TODO(), request)
			assert.Nil(t, err)
			assert.Equal(t, int32(0), response.ArtifactCount)
		})

		t.Run(backend+" returns artifacts for workflows", func(t *testing.T) {
			request := &artifacthub.CountArtifactsRequest{
				Category:   artifacthub.CountArtifactsRequest_WORKFLOW,
				CategoryId: "first",
				ArtifactId: artifactId,
			}

			response, err := server.CountArtifacts(context.TODO(), request)
			assert.Nil(t, err)
			assert.Equal(t, int32(2), response.ArtifactCount)

			request = &artifacthub.CountArtifactsRequest{
				Category:   artifacthub.CountArtifactsRequest_WORKFLOW,
				CategoryId: "second",
				ArtifactId: artifactId,
			}

			response, err = server.CountArtifacts(context.TODO(), request)
			assert.Nil(t, err)
			assert.Equal(t, int32(5), response.ArtifactCount)

			request = &artifacthub.CountArtifactsRequest{
				Category:   artifacthub.CountArtifactsRequest_WORKFLOW,
				CategoryId: "notfound",
				ArtifactId: artifactId,
			}

			response, err = server.CountArtifacts(context.TODO(), request)
			assert.Nil(t, err)
			assert.Equal(t, int32(0), response.ArtifactCount)
		})

		t.Run(backend+" returns artifacts for jobs", func(t *testing.T) {
			request := &artifacthub.CountArtifactsRequest{
				Category:   artifacthub.CountArtifactsRequest_JOB,
				CategoryId: "first",
				ArtifactId: artifactId,
			}

			response, err := server.CountArtifacts(context.TODO(), request)
			assert.Nil(t, err)
			assert.Equal(t, int32(3), response.ArtifactCount)

			request = &artifacthub.CountArtifactsRequest{
				Category:   artifacthub.CountArtifactsRequest_JOB,
				CategoryId: "second",
				ArtifactId: artifactId,
			}

			response, err = server.CountArtifacts(context.TODO(), request)
			assert.Nil(t, err)
			assert.Equal(t, int32(1), response.ArtifactCount)

			request = &artifacthub.CountArtifactsRequest{
				Category:   artifacthub.CountArtifactsRequest_JOB,
				CategoryId: "notfound",
				ArtifactId: artifactId,
			}

			response, err = server.CountArtifacts(context.TODO(), request)
			assert.Nil(t, err)
			assert.Equal(t, int32(0), response.ArtifactCount)
		})
	})
}

func Test__ListPath(t *testing.T) {
	storage.RunTestForAllBackends(t, func(backend string, client storage.Client) {
		models.PrepareDatabaseForTests()
		server := Server{StorageClient: client}

		idempotencyToken := "request-token-1"
		response, err := server.Create(context.TODO(), &artifacthub.CreateRequest{RequestToken: idempotencyToken})
		if !assert.Nil(t, err) {
			return
		}

		options := storage.BucketOptions{
			Name:       response.Artifact.BucketName,
			PathPrefix: idempotencyToken,
		}

		err = storage.SeedBucket(client.GetBucket(options), seedObjects())
		if !assert.Nil(t, err) {
			return
		}

		artifactId := response.Artifact.Id

		t.Run(backend+" list path that does not exist", func(t *testing.T) {
			request := &artifacthub.ListPathRequest{
				ArtifactId: artifactId,
				Path:       "path/not/found",
			}

			response, err := server.ListPath(context.TODO(), request)
			assert.Nil(t, err)
			assert.Empty(t, response.Items)
		})

		t.Run(backend+" list root path", func(t *testing.T) {
			request := &artifacthub.ListPathRequest{
				ArtifactId: artifactId,
				Path:       "",
			}

			response, err := server.ListPath(context.TODO(), request)
			assert.Nil(t, err)
			assert.Equal(t, []*artifacthub.ListItem{
				{Name: "artifacts/", IsDirectory: true},
			}, response.Items)
		})

		t.Run(backend+" list path with directories only", func(t *testing.T) {
			request := &artifacthub.ListPathRequest{
				ArtifactId: artifactId,
				Path:       "artifacts/",
			}

			response, err := server.ListPath(context.TODO(), request)
			assert.Nil(t, err)
			assert.Equal(t, []*artifacthub.ListItem{
				{Name: "artifacts/jobs/", IsDirectory: true},
				{Name: "artifacts/projects/", IsDirectory: true},
				{Name: "artifacts/workflows/", IsDirectory: true},
			}, response.Items)
		})

		t.Run(backend+" list path with directory and file", func(t *testing.T) {
			request := &artifacthub.ListPathRequest{
				ArtifactId: artifactId,
				Path:       "artifacts/projects/first/",
			}

			response, err := server.ListPath(context.TODO(), request)
			assert.Nil(t, err)
			assert.Equal(t, []*artifacthub.ListItem{
				{Name: "artifacts/projects/first/file1.txt", IsDirectory: false, Size: 5},
				{Name: "artifacts/projects/first/dir/", IsDirectory: true, Size: 0},
			}, response.Items)
		})

		t.Run(backend+" list path unwrapping directories", func(t *testing.T) {
			request := &artifacthub.ListPathRequest{
				ArtifactId:        artifactId,
				Path:              "artifacts/projects/first/",
				UnwrapDirectories: true,
			}

			response, err := server.ListPath(context.TODO(), request)
			assert.Nil(t, err)
			assert.Equal(t, []*artifacthub.ListItem{
				{Name: "artifacts/projects/first/dir/subfile1.txt", IsDirectory: false, Size: 5},
				{Name: "artifacts/projects/first/dir/subfile2.txt", IsDirectory: false, Size: 5},
				{Name: "artifacts/projects/first/file1.txt", IsDirectory: false, Size: 5},
			}, response.Items)
		})
	})
}

func Test__Describe(t *testing.T) {
	models.PrepareDatabaseForTests()
	server := Server{}

	t.Run("when the artifact bucket ID is not a valid UUID", func(t *testing.T) {
		request := &artifacthub.DescribeRequest{ArtifactId: "haha-im-invalid"}

		_, err := server.Describe(context.TODO(), request)
		assert.NotNil(t, err)
		assert.Equal(t, "rpc error: code = FailedPrecondition desc = artifact bucket ID is malformed", err.Error())
	})

	t.Run("when the bucket don't exist", func(t *testing.T) {
		request := &artifacthub.DescribeRequest{ArtifactId: uuid.NewV4().String()}

		_, err := server.Describe(context.TODO(), request)
		assert.NotNil(t, err)
		assert.Equal(t, "rpc error: code = NotFound desc = Finding Artifact row by ID in the db: record not found", err.Error())
	})

	a, err := models.CreateArtifact("test-bucket-1", uuid.NewV4().String())
	require.Nil(t, err)

	t.Run("when bucket exists", func(t *testing.T) {
		request := &artifacthub.DescribeRequest{ArtifactId: a.ID.String()}

		response, err := server.Describe(context.TODO(), request)
		assert.Nil(t, err)
		assert.Equal(t, "test-bucket-1", response.Artifact.BucketName)
	})

	t.Run("when bucket does not have retention policy", func(t *testing.T) {
		request := &artifacthub.DescribeRequest{ArtifactId: a.ID.String(), IncludeRetentionPolicy: true}

		response, err := server.Describe(context.TODO(), request)
		assert.Nil(t, err)
		assert.Equal(t, "test-bucket-1", response.Artifact.BucketName)
		assert.Equal(t, 0, len(response.RetentionPolicy.ProjectLevelRetentionPolicies))
		assert.Equal(t, 0, len(response.RetentionPolicy.WorkflowLevelRetentionPolicies))
		assert.Equal(t, 0, len(response.RetentionPolicy.JobLevelRetentionPolicies))
	})

	rules := models.RetentionPolicyRules{
		Rules: []models.RetentionPolicyRuleItem{
			{Selector: "/aaa", Age: 7 * 24 * 3600},
		},
	}

	_, err = models.CreateRetentionPolicy(a.ID, rules, rules, rules)
	require.Nil(t, err)

	t.Run("when bucket has retention policy", func(t *testing.T) {
		request := &artifacthub.DescribeRequest{ArtifactId: a.ID.String(), IncludeRetentionPolicy: true}

		response, err := server.Describe(context.TODO(), request)
		assert.Nil(t, err)
		assert.Equal(t, "test-bucket-1", response.Artifact.BucketName)
		assert.Equal(t, 1, len(response.RetentionPolicy.ProjectLevelRetentionPolicies))
		assert.Equal(t, 1, len(response.RetentionPolicy.WorkflowLevelRetentionPolicies))
		assert.Equal(t, 1, len(response.RetentionPolicy.JobLevelRetentionPolicies))

		assert.Equal(t, "/aaa", response.RetentionPolicy.ProjectLevelRetentionPolicies[0].Selector)
		assert.Equal(t, "/aaa", response.RetentionPolicy.WorkflowLevelRetentionPolicies[0].Selector)
		assert.Equal(t, "/aaa", response.RetentionPolicy.JobLevelRetentionPolicies[0].Selector)
	})
}

func Test__Destroy(t *testing.T) {
	models.PrepareDatabaseForTests()
	server := Server{}

	t.Run("creates retention policy for deletion", func(t *testing.T) {
		a, err := models.CreateArtifact("test-bucket", uuid.NewV4().String())
		require.Nil(t, err)
		assert.Nil(t, a.DeletedAt)

		// no retention policy
		_, err = models.FindRetentionPolicy(a.ID)
		assert.ErrorIs(t, err, gorm.ErrRecordNotFound)

		_, err = server.Destroy(context.TODO(), &artifacthub.DestroyRequest{ArtifactId: a.ID.String()})
		assert.NoError(t, err)

		// artifact record still exists, but has deleted_at and retention policy set
		a, err = models.FindArtifactByID(a.ID.String())
		assert.NoError(t, err)
		assert.NotNil(t, a.DeletedAt)
		r, err := models.FindRetentionPolicy(a.ID)
		assert.NoError(t, err)
		if assert.NotNil(t, r) {
			rule := models.RetentionPolicyRules{
				Rules: []models.RetentionPolicyRuleItem{
					{Selector: "/**/*", Age: models.MinRetentionPolicyAge},
				},
			}

			assert.Equal(t, r.ArtifactID, a.ID)
			assert.Equal(t, r.ProjectLevelPolicies, rule)
			assert.Equal(t, r.WorkflowLevelPolicies, rule)
			assert.Equal(t, r.JobLevelPolicies, rule)
		}
	})

	t.Run("overrides current retention policy for deletion", func(t *testing.T) {
		previousRule := models.RetentionPolicyRules{
			Rules: []models.RetentionPolicyRuleItem{
				{Selector: "/my-dir/*", Age: 3600 * 24 * 7},
			},
		}

		a, err := models.CreateArtifact("test-bucket-2", uuid.NewV4().String())
		require.Nil(t, err)
		assert.Nil(t, a.DeletedAt)
		_, err = models.CreateRetentionPolicy(a.ID, previousRule, previousRule, previousRule)
		assert.NoError(t, err)

		_, err = server.Destroy(context.TODO(), &artifacthub.DestroyRequest{ArtifactId: a.ID.String()})
		assert.NoError(t, err)

		// artifact record still exists, but has deleted_at and updated retention policy set
		a, err = models.FindArtifactByID(a.ID.String())
		assert.NoError(t, err)
		assert.NotNil(t, a.DeletedAt)
		r, err := models.FindRetentionPolicy(a.ID)
		assert.NoError(t, err)
		if assert.NotNil(t, r) {
			rule := models.RetentionPolicyRules{
				Rules: []models.RetentionPolicyRuleItem{
					{Selector: "/**/*", Age: models.MinRetentionPolicyAge},
				},
			}

			assert.Equal(t, r.ArtifactID, a.ID)
			assert.Equal(t, r.ProjectLevelPolicies, rule)
			assert.Equal(t, r.WorkflowLevelPolicies, rule)
			assert.Equal(t, r.JobLevelPolicies, rule)
		}
	})
}

func Test__UpdateRetentionPolicy(t *testing.T) {
	models.PrepareDatabaseForTests()
	server := Server{}

	a, err := models.CreateArtifact("test-bucket", uuid.NewV4().String())
	require.Nil(t, err)

	t.Run("when the artifact bucket ID is not a valid UUID", func(t *testing.T) {
		request := &artifacthub.UpdateRetentionPolicyRequest{ArtifactId: "haha-im-invalid"}

		_, err := server.UpdateRetentionPolicy(context.TODO(), request)
		assert.NotNil(t, err)
		assert.Equal(t, "rpc error: code = FailedPrecondition desc = artifact bucket ID is malformed", err.Error())
	})

	t.Run("when there are is no retention policy attached to the bucket, the system will create a new one", func(t *testing.T) {
		request := &artifacthub.UpdateRetentionPolicyRequest{
			ArtifactId: a.ID.String(),
			RetentionPolicy: &artifacthub.RetentionPolicy{
				ProjectLevelRetentionPolicies: []*artifacthub.RetentionPolicy_RetentionPolicyRule{
					{Selector: "/abc", Age: 7 * 24 * 3600},
				},
			},
		}

		response, err := server.UpdateRetentionPolicy(context.TODO(), request)
		assert.Nil(t, err)

		assert.Equal(t, "/abc", response.RetentionPolicy.ProjectLevelRetentionPolicies[0].Selector)
		assert.Equal(t, int64(7*24*3600), response.RetentionPolicy.ProjectLevelRetentionPolicies[0].Age)
	})

	t.Run("updating existing policy", func(t *testing.T) {
		request := &artifacthub.UpdateRetentionPolicyRequest{
			ArtifactId: a.ID.String(),
			RetentionPolicy: &artifacthub.RetentionPolicy{
				ProjectLevelRetentionPolicies: []*artifacthub.RetentionPolicy_RetentionPolicyRule{
					{Selector: "/abcd", Age: 7 * 24 * 3600},
				},
			},
		}

		response, err := server.UpdateRetentionPolicy(context.TODO(), request)
		assert.Nil(t, err)

		assert.Equal(t, "/abcd", response.RetentionPolicy.ProjectLevelRetentionPolicies[0].Selector)
		assert.Equal(t, int64(7*24*3600), response.RetentionPolicy.ProjectLevelRetentionPolicies[0].Age)
	})
}

func Test__GenerateToken(t *testing.T) {
	models.PrepareDatabaseForTests()
	jwtSecret := "hello"
	server := Server{jwtSecret: jwtSecret}

	t.Run("invalid requests -> error", func(t *testing.T) {
		v := uuid.NewV4().String()
		requests := []*artifacthub.GenerateTokenRequest{
			{ProjectId: "not-valid-uuid"},
			{JobId: "not-valid-uuid"},
			{ArtifactId: "not-valid-uuid"},
			{WorkflowId: "not-valid-uuid"},
			{ProjectId: v, JobId: v, WorkflowId: v},
			{ArtifactId: v, JobId: v, WorkflowId: v},
			{ProjectId: v, ArtifactId: v, WorkflowId: v},
		}

		for _, request := range requests {
			response, err := server.GenerateToken(context.Background(), request)
			assert.Error(t, err)
			assert.Nil(t, response)
			assert.Equal(t, codes.InvalidArgument, status.Code(err))
		}
	})

	t.Run("workflow ID can empty", func(t *testing.T) {
		v := uuid.NewV4().String()
		req := &artifacthub.GenerateTokenRequest{
			ProjectId:  v,
			ArtifactId: v,
			JobId:      v,
		}

		response, err := server.GenerateToken(context.Background(), req)
		assert.NoError(t, err)
		assert.NotEmpty(t, response.Token)
	})

	t.Run("duration has a limit of 24h", func(t *testing.T) {
		v := uuid.NewV4().String()
		req := &artifacthub.GenerateTokenRequest{
			ProjectId:  v,
			ArtifactId: v,
			JobId:      v,
			Duration:   uint32(25 * time.Hour / time.Second),
		}

		_, err := server.GenerateToken(context.Background(), req)
		assert.Error(t, err)
		assert.Equal(t, codes.InvalidArgument, status.Code(err))
	})

	t.Run("valid request generates token", func(t *testing.T) {
		request := &artifacthub.GenerateTokenRequest{
			ArtifactId: uuid.NewV4().String(),
			ProjectId:  uuid.NewV4().String(),
			JobId:      uuid.NewV4().String(),
			WorkflowId: uuid.NewV4().String(),
			Duration:   uint32(24 * time.Hour / time.Second),
		}

		response, err := server.GenerateToken(context.Background(), request)
		assert.NoError(t, err)
		assert.NotEmpty(t, response.Token)

		claims, err := jwt.ValidateToken(response.Token, jwtSecret, func(claims gojwt.MapClaims) error {
			if request.JobId != claims["job"] {
				return fmt.Errorf("bad job")
			}

			if request.ProjectId != claims["project"] {
				return fmt.Errorf("bad project")
			}

			if request.WorkflowId != claims["workflow"] {
				return fmt.Errorf("bad workflow")
			}

			return nil
		})

		assert.NoError(t, err)
		assert.Equal(t, claims.ArtifactID, request.ArtifactId)
		assert.Equal(t, claims.Project, request.ProjectId)
		assert.Equal(t, claims.Workflow, request.WorkflowId)
		assert.Equal(t, claims.Job, request.JobId)
	})
}

func Test__GrpcServer(t *testing.T) {
	bufSize := 1024 * 50
	lis := bufconn.Listen(bufSize)
	defer lis.Close()
	bufDialer := func(context.Context, string) (net.Conn, error) {
		return lis.Dial()
	}

	models.PrepareDatabaseForTests()

	maxMsgSize := 1024
	os.Setenv("MAX_PRIVATE_RECEIVE_MSG_SIZE", strconv.Itoa(maxMsgSize))
	defer os.Unsetenv("MAX_PRIVATE_RECEIVE_MSG_SIZE")

	storageClient, err := storage.NewGcsClient("")
	assert.Nil(t, err)

	s := &Server{
		Port: 50333,
		recoveryHandler: func(p interface{}) (err error) {
			return status.Errorf(codes.Internal, "panic triggered: %v", p)
		},
		StorageClient: storageClient,
	}
	go func() {
		s.serveWithListener(lis)
	}()
	time.Sleep(1 * time.Second)
	conn, err := grpc.DialContext(context.TODO(), "bufnet", grpc.WithContextDialer(bufDialer), grpc.WithInsecure())
	if err != nil {
		t.Fatalf("failed to dial bufnet: %v", err)
	}
	defer conn.Close()

	client := artifacthub.NewArtifactServiceClient(conn)

	// test sending a message smaller than max message size limit
	var smallToken strings.Builder
	overHead := 100
	for smallToken.Len() < maxMsgSize-overHead {
		smallToken.WriteString("a")
	}

	req := &artifacthub.CreateRequest{RequestToken: smallToken.String()}

	_, err = client.Create(context.TODO(), req)
	assert.NoError(t, err)

	// test sending a message larger than max message size limit
	var largeToken strings.Builder
	for largeToken.Len() <= maxMsgSize {
		largeToken.WriteString("a")
	}
	req = &artifacthub.CreateRequest{RequestToken: largeToken.String()}

	_, err = client.Create(context.TODO(), req)
	assert.Error(t, err)

	st, ok := status.FromError(err)
	assert.True(t, ok)
	assert.Equal(t, codes.ResourceExhausted, st.Code())
	assert.Contains(t, st.Message(), "received message larger than max")
}

func seedObjects() []storage.SeedObject {
	return []storage.SeedObject{

		// project artifacts
		{Name: "artifacts/projects/first/file1.txt", Content: "hello"},
		{Name: "artifacts/projects/first/dir/subfile1.txt", Content: "hello"},
		{Name: "artifacts/projects/first/dir/subfile2.txt", Content: "hello"},
		{Name: "artifacts/projects/second/dir/subfile1.txt", Content: "hello"},
		{Name: "artifacts/projects/second/dir/subfile2.txt", Content: "hello"},

		// workflow artifacts
		{Name: "artifacts/workflows/first/dir/subfile1.txt", Content: "hello"},
		{Name: "artifacts/workflows/first/dir/subfile2.txt", Content: "hello"},
		{Name: "artifacts/workflows/second/file1.txt", Content: "hello"},
		{Name: "artifacts/workflows/second/file2.txt", Content: "hello"},
		{Name: "artifacts/workflows/second/file3.txt", Content: "hello"},
		{Name: "artifacts/workflows/second/dir/subfile1.txt", Content: "hello"},
		{Name: "artifacts/workflows/second/dir/subfile2.txt", Content: "hello"},

		// job artifacts
		{Name: "artifacts/jobs/first/file1.txt", Content: "hello"},
		{Name: "artifacts/jobs/first/dir/subfile1.txt", Content: "hello"},
		{Name: "artifacts/jobs/first/dir/subdir/subfile2.txt", Content: "hello"},
		{Name: "artifacts/jobs/second/dir/subfile1.txt", Content: "hello"},
	}
}
