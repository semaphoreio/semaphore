package publicserver

import (
	"context"
	"fmt"
	"net"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"

	uuid "github.com/satori/go.uuid"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/api/descriptors/artifacts"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/jwt"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/models"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/storage"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
	"google.golang.org/grpc/test/bufconn"
)

var (
	JWTSecret   = "very-important-secret"
	AuthTypeJWT = "jwt"
)

func Test__BadRequests(t *testing.T) {
	storage.RunTestForAllBackends(t, func(backend string, client storage.Client) {
		for _, resourceType := range ResourceTypes {
			t.Run(fmt.Sprintf("%s/%s/no auth", backend, resourceType), func(t *testing.T) {
				server, claims, _ := prepareTest(t, resourceType, client)
				p := getPath(resourceType, claims, "newfile1.txt")
				request := &artifacts.GenerateSignedURLsRequest{
					Type:  artifacts.GenerateSignedURLsRequest_PUSH,
					Paths: []string{p},
				}

				_, err := server.GenerateSignedURLs(context.Background(), request)
				require.Error(t, err)
				assert.Equal(t, codes.Unauthenticated, status.Code(err))
			})

			t.Run(fmt.Sprintf("%s/%s/auth is not a jwt", backend, resourceType), func(t *testing.T) {
				server, claims, _ := prepareTest(t, resourceType, client)
				p := getPath(resourceType, claims, "newfile1.txt")
				ctx := metadata.NewIncomingContext(context.Background(), metadata.MD{
					"authorization": []string{uuid.NewV4().String()},
				})

				request := &artifacts.GenerateSignedURLsRequest{
					Type:  artifacts.GenerateSignedURLsRequest_PUSH,
					Paths: []string{p},
				}

				_, err := server.GenerateSignedURLs(ctx, request)
				require.Error(t, err)
				assert.Equal(t, codes.PermissionDenied, status.Code(err))
			})

			t.Run(fmt.Sprintf("%s/%s/invalid path structure", backend, resourceType), func(t *testing.T) {
				server, _, ctx := prepareTest(t, resourceType, client)
				p := "not/a/valid/path/file1.txt"

				request := &artifacts.GenerateSignedURLsRequest{
					Type:  artifacts.GenerateSignedURLsRequest_PUSH,
					Paths: []string{p},
				}

				_, err := server.GenerateSignedURLs(ctx, request)
				require.Error(t, err)
				assert.Equal(t, codes.InvalidArgument, status.Code(err))
				assert.Contains(t, err.Error(), "invalid path")
			})

			t.Run(fmt.Sprintf("%s/%s/paths with different resource type and ID", backend, resourceType), func(t *testing.T) {
				server, claims, ctx := prepareTest(t, resourceType, client)
				request := &artifacts.GenerateSignedURLsRequest{
					Type: artifacts.GenerateSignedURLsRequest_PUSH,
					Paths: []string{
						getPath(resourceType, claims, "file1.txt"),
						fmt.Sprintf("artifacts/projects/%s/file2.txt", uuid.NewV4().String()),
					},
				}

				_, err := server.GenerateSignedURLs(ctx, request)
				require.Error(t, err)
				assert.Equal(t, codes.InvalidArgument, status.Code(err))
				assert.Contains(t, err.Error(), "invalid resource in path")
			})

			t.Run(fmt.Sprintf("%s/%s/resource iD in request does not match claim in JWT", backend, resourceType), func(t *testing.T) {
				server, _, ctx := prepareTest(t, resourceType, client)

				// use other ID in request path
				otherClaims := jwt.Claims{
					Job:      uuid.NewV4().String(),
					Workflow: uuid.NewV4().String(),
					Project:  uuid.NewV4().String(),
				}

				p := getPath(resourceType, otherClaims, "file1.txt")
				request := &artifacts.GenerateSignedURLsRequest{
					Type:  artifacts.GenerateSignedURLsRequest_PUSH,
					Paths: []string{p},
				}

				_, err := server.GenerateSignedURLs(ctx, request)
				require.Error(t, err)
				assert.Equal(t, codes.PermissionDenied, status.Code(err))
				assert.Contains(t, err.Error(), fmt.Sprintf("invalid claim: %s", resourceType[0:len(resourceType)-1]))
			})

			t.Run(fmt.Sprintf("%s/%s/no iD in request", backend, resourceType), func(t *testing.T) {
				server, _, ctx := prepareTest(t, resourceType, client)

				p := fmt.Sprintf("artifacts/%s//file1.txt", resourceType)
				request := &artifacts.GenerateSignedURLsRequest{
					Type:  artifacts.GenerateSignedURLsRequest_PUSH,
					Paths: []string{p},
				}

				_, err := server.GenerateSignedURLs(ctx, request)
				require.Error(t, err)
				assert.Equal(t, codes.InvalidArgument, status.Code(err))
				assert.Contains(t, err.Error(), fmt.Sprintf("invalid path %s", p))
			})

			t.Run(fmt.Sprintf("%s/%s/bad jwt signature", backend, resourceType), func(t *testing.T) {
				server, claims, ctx := prepareTest(t, resourceType, client)
				server.jwtSecret = "another-one"

				p := getPath(resourceType, claims, "file1.txt")
				request := &artifacts.GenerateSignedURLsRequest{
					Type:  artifacts.GenerateSignedURLsRequest_PUSH,
					Paths: []string{p},
				}

				_, err := server.GenerateSignedURLs(ctx, request)
				require.Error(t, err)
				assert.Equal(t, codes.PermissionDenied, status.Code(err))
				assert.Contains(t, err.Error(), "token signature is invalid")
			})
		}
	})
}

func Test__EmptyWorkflowJWTClaimHasNoAccessToAnyWorkflows(t *testing.T) {
	storage.RunTestForAllBackends(t, func(backend string, client storage.Client) {
		baseClaims := jwt.Claims{
			Project:  uuid.NewV4().String(),
			Job:      uuid.NewV4().String(),
			Workflow: "",
		}

		server, _, ctx := prepareTestWithClaims(t, ResourceTypeWorkflows, client, baseClaims)
		p := fmt.Sprintf("artifacts/%s/%s/file1.txt", ResourceTypeWorkflows, uuid.NewV4().String())
		request := &artifacts.GenerateSignedURLsRequest{
			Type:  artifacts.GenerateSignedURLsRequest_PUSHFORCE,
			Paths: []string{p},
		}

		_, err := server.GenerateSignedURLs(ctx, request)
		require.Error(t, err)
		assert.Equal(t, codes.PermissionDenied, status.Code(err))
		assert.Contains(t, err.Error(), "invalid claim: workflow")
	})
}

func Test__GetSignedURLForPush(t *testing.T) {
	storage.RunTestForAllBackends(t, func(backend string, client storage.Client) {
		for _, resourceType := range ResourceTypes {
			t.Run(fmt.Sprintf("%s/%s/ no paths", backend, resourceType), func(t *testing.T) {
				server, _, ctx := prepareTest(t, resourceType, client)
				request := &artifacts.GenerateSignedURLsRequest{
					Type:  artifacts.GenerateSignedURLsRequest_PUSH,
					Paths: []string{},
				}

				response, err := server.GenerateSignedURLs(ctx, request)
				require.NoError(t, err)
				assert.Len(t, response.URLs, 0)
			})

			t.Run(fmt.Sprintf("%s/%s/single path", backend, resourceType), func(t *testing.T) {
				server, claims, ctx := prepareTest(t, resourceType, client)
				p := getPath(resourceType, claims, "newfile1.txt")
				request := &artifacts.GenerateSignedURLsRequest{
					Type:  artifacts.GenerateSignedURLsRequest_PUSH,
					Paths: []string{p},
				}

				response, err := server.GenerateSignedURLs(ctx, request)
				require.Nil(t, err)
				require.Len(t, response.URLs, 2)
				assert.Equal(t, response.URLs[0].Method, artifacts.SignedURL_HEAD)
				assert.Contains(t, response.URLs[0].URL, p)
				assert.Equal(t, response.URLs[1].Method, artifacts.SignedURL_PUT)
				assert.Contains(t, response.URLs[1].URL, p)
			})

			t.Run(fmt.Sprintf("%s/%s/multiple paths", backend, resourceType), func(t *testing.T) {
				server, claims, ctx := prepareTest(t, resourceType, client)
				request := &artifacts.GenerateSignedURLsRequest{
					Type: artifacts.GenerateSignedURLsRequest_PUSH,
					Paths: []string{
						getPath(resourceType, claims, "newfile1.txt"),
						getPath(resourceType, claims, "newfile2.txt"),
						getPath(resourceType, claims, "newfile3.txt"),
					},
				}

				response, err := server.GenerateSignedURLs(ctx, request)
				require.Nil(t, err)
				require.Len(t, response.URLs, 6)
				assert.Equal(t, response.URLs[0].Method, artifacts.SignedURL_HEAD)
				assert.Contains(t, response.URLs[0].URL, getPath(resourceType, claims, "newfile1.txt"))
				assert.Equal(t, response.URLs[1].Method, artifacts.SignedURL_PUT)
				assert.Contains(t, response.URLs[1].URL, getPath(resourceType, claims, "newfile1.txt"))
				assert.Equal(t, response.URLs[2].Method, artifacts.SignedURL_HEAD)
				assert.Contains(t, response.URLs[2].URL, getPath(resourceType, claims, "newfile2.txt"))
				assert.Equal(t, response.URLs[3].Method, artifacts.SignedURL_PUT)
				assert.Contains(t, response.URLs[3].URL, getPath(resourceType, claims, "newfile2.txt"))
				assert.Equal(t, response.URLs[4].Method, artifacts.SignedURL_HEAD)
				assert.Contains(t, response.URLs[4].URL, getPath(resourceType, claims, "newfile3.txt"))
				assert.Equal(t, response.URLs[5].Method, artifacts.SignedURL_PUT)
				assert.Contains(t, response.URLs[5].URL, getPath(resourceType, claims, "newfile3.txt"))
			})
		}
	})
}

func Test__GetSignedURLForForcePush(t *testing.T) {
	storage.RunTestForAllBackends(t, func(backend string, client storage.Client) {
		for _, resourceType := range ResourceTypes {
			t.Run(fmt.Sprintf("%s/%s/no paths", backend, resourceType), func(t *testing.T) {
				server, _, ctx := prepareTest(t, resourceType, client)
				request := &artifacts.GenerateSignedURLsRequest{
					Type:  artifacts.GenerateSignedURLsRequest_PUSHFORCE,
					Paths: []string{},
				}

				response, err := server.GenerateSignedURLs(ctx, request)
				require.Nil(t, err)
				assert.Len(t, response.URLs, 0)
			})

			t.Run(fmt.Sprintf("%s/%s/single path", backend, resourceType), func(t *testing.T) {
				server, claims, ctx := prepareTest(t, resourceType, client)
				p := getPath(resourceType, claims, "newfile1.txt")
				request := &artifacts.GenerateSignedURLsRequest{
					Type:  artifacts.GenerateSignedURLsRequest_PUSHFORCE,
					Paths: []string{p},
				}

				response, err := server.GenerateSignedURLs(ctx, request)
				require.Nil(t, err)
				require.Len(t, response.URLs, 1)
				assert.Equal(t, response.URLs[0].Method, artifacts.SignedURL_PUT)
				assert.Contains(t, response.URLs[0].URL, p)
			})

			t.Run(fmt.Sprintf("%s/%s/multiple paths", backend, resourceType), func(t *testing.T) {
				server, claims, ctx := prepareTest(t, resourceType, client)
				request := &artifacts.GenerateSignedURLsRequest{
					Type: artifacts.GenerateSignedURLsRequest_PUSHFORCE,
					Paths: []string{
						getPath(resourceType, claims, "newfile1.txt"),
						getPath(resourceType, claims, "newfile2.txt"),
						getPath(resourceType, claims, "newfile3.txt"),
					},
				}

				response, err := server.GenerateSignedURLs(ctx, request)
				require.Nil(t, err)
				require.Len(t, response.URLs, 3)
				assert.Equal(t, response.URLs[0].Method, artifacts.SignedURL_PUT)
				assert.Contains(t, response.URLs[0].URL, getPath(resourceType, claims, "newfile1.txt"))
				assert.Equal(t, response.URLs[1].Method, artifacts.SignedURL_PUT)
				assert.Contains(t, response.URLs[1].URL, getPath(resourceType, claims, "newfile2.txt"))
				assert.Equal(t, response.URLs[2].Method, artifacts.SignedURL_PUT)
				assert.Contains(t, response.URLs[2].URL, getPath(resourceType, claims, "newfile3.txt"))
			})
		}
	})
}

func Test__GetSignedURLForPull(t *testing.T) {
	storage.RunTestForAllBackends(t, func(backend string, client storage.Client) {
		for _, resourceType := range ResourceTypes {
			t.Run(fmt.Sprintf("%s/%s/no paths", backend, resourceType), func(t *testing.T) {
				server, _, ctx := prepareTest(t, resourceType, client)
				request := &artifacts.GenerateSignedURLsRequest{
					Type:  artifacts.GenerateSignedURLsRequest_PULL,
					Paths: []string{},
				}

				response, err := server.GenerateSignedURLs(ctx, request)
				require.Nil(t, err)
				assert.Len(t, response.URLs, 0)
			})

			t.Run(fmt.Sprintf("%s/%s/pull for missing file => error", backend, resourceType), func(t *testing.T) {
				server, claims, ctx := prepareTest(t, resourceType, client)
				p := getPath(resourceType, claims, "not/found/file1.txt")
				request := &artifacts.GenerateSignedURLsRequest{
					Type:  artifacts.GenerateSignedURLsRequest_PULL,
					Paths: []string{p},
				}

				_, err := server.GenerateSignedURLs(ctx, request)
				assert.Error(t, err)
			})

			t.Run(fmt.Sprintf("%s/%s/single existing file", backend, resourceType), func(t *testing.T) {
				server, claims, ctx := prepareTest(t, resourceType, client)
				p := getPath(resourceType, claims, "first/file1.txt")
				request := &artifacts.GenerateSignedURLsRequest{
					Type:  artifacts.GenerateSignedURLsRequest_PULL,
					Paths: []string{p},
				}

				response, err := server.GenerateSignedURLs(ctx, request)
				require.Nil(t, err)
				require.Len(t, response.URLs, 1)
				assert.Equal(t, response.URLs[0].Method, artifacts.SignedURL_GET)
				assert.Contains(t, response.URLs[0].URL, p)
			})

			t.Run(fmt.Sprintf("%s/%s/multiple files only uses the first", backend, resourceType), func(t *testing.T) {
				server, claims, ctx := prepareTest(t, resourceType, client)
				request := &artifacts.GenerateSignedURLsRequest{
					Type: artifacts.GenerateSignedURLsRequest_PULL,
					Paths: []string{
						getPath(resourceType, claims, "first/file1.txt"),
						getPath(resourceType, claims, "first/file2.txt"),
					},
				}

				response, err := server.GenerateSignedURLs(ctx, request)
				require.Nil(t, err)
				require.Len(t, response.URLs, 1)
				assert.Equal(t, response.URLs[0].Method, artifacts.SignedURL_GET)
				assert.Contains(t, response.URLs[0].URL, getPath(resourceType, claims, "first/file1.txt"))
			})

			t.Run(fmt.Sprintf("%s/%s/existing dir generates URLs for all files in it", backend, resourceType), func(t *testing.T) {
				server, claims, ctx := prepareTest(t, resourceType, client)
				request := &artifacts.GenerateSignedURLsRequest{
					Type:  artifacts.GenerateSignedURLsRequest_PULL,
					Paths: []string{getPath(resourceType, claims, "first/")},
				}

				response, err := server.GenerateSignedURLs(ctx, request)
				require.Nil(t, err)
				require.Len(t, response.URLs, 2)
				assert.Equal(t, response.URLs[0].Method, artifacts.SignedURL_GET)
				assert.Contains(t, response.URLs[0].URL, getPath(resourceType, claims, "first/file1.txt"))
				assert.Equal(t, response.URLs[1].Method, artifacts.SignedURL_GET)
				assert.Contains(t, response.URLs[1].URL, getPath(resourceType, claims, "first/file2.txt"))
			})
		}
	})
}

func Test__GetSignedURLForYank(t *testing.T) {
	storage.RunTestForAllBackends(t, func(backend string, client storage.Client) {
		for _, resourceType := range ResourceTypes {
			t.Run(fmt.Sprintf("%s/%s/no paths", backend, resourceType), func(t *testing.T) {
				server, _, ctx := prepareTest(t, resourceType, client)
				request := &artifacts.GenerateSignedURLsRequest{
					Type:  artifacts.GenerateSignedURLsRequest_YANK,
					Paths: []string{},
				}

				response, err := server.GenerateSignedURLs(ctx, request)
				require.Nil(t, err)
				assert.Len(t, response.URLs, 0)
			})

			t.Run(fmt.Sprintf("%s/%s/path to file generates single URL to file", backend, resourceType), func(t *testing.T) {
				server, claims, ctx := prepareTest(t, resourceType, client)
				p := getPath(resourceType, claims, "first/file1.txt")
				request := &artifacts.GenerateSignedURLsRequest{
					Type:  artifacts.GenerateSignedURLsRequest_YANK,
					Paths: []string{p},
				}

				response, err := server.GenerateSignedURLs(ctx, request)
				require.Nil(t, err)
				require.Len(t, response.URLs, 1)
				assert.Equal(t, response.URLs[0].Method, artifacts.SignedURL_DELETE)
				assert.Contains(t, response.URLs[0].URL, p)
			})

			t.Run(fmt.Sprintf("%s/%s/path to missimg file -> error", backend, resourceType), func(t *testing.T) {
				server, claims, ctx := prepareTest(t, resourceType, client)
				request := &artifacts.GenerateSignedURLsRequest{
					Type:  artifacts.GenerateSignedURLsRequest_YANK,
					Paths: []string{getPath(resourceType, claims, "not/found/file1.txt")},
				}

				_, err := server.GenerateSignedURLs(ctx, request)
				assert.Error(t, err)
			})

			t.Run(fmt.Sprintf("%s/%s/path to dir generates URLs for all files in it", backend, resourceType), func(t *testing.T) {
				server, claims, ctx := prepareTest(t, resourceType, client)
				request := &artifacts.GenerateSignedURLsRequest{
					Type:  artifacts.GenerateSignedURLsRequest_YANK,
					Paths: []string{getPath(resourceType, claims, "first")},
				}

				response, err := server.GenerateSignedURLs(ctx, request)
				require.Nil(t, err)
				require.Len(t, response.URLs, 2)
				assert.Equal(t, response.URLs[0].Method, artifacts.SignedURL_DELETE)
				assert.Contains(t, response.URLs[0].URL, getPath(resourceType, claims, "first/file1.txt"))
				assert.Equal(t, response.URLs[1].Method, artifacts.SignedURL_DELETE)
				assert.Contains(t, response.URLs[1].URL, getPath(resourceType, claims, "first/file2.txt"))
			})

			t.Run(fmt.Sprintf("%s/%s/multiple file paths uses only the first", backend, resourceType), func(t *testing.T) {
				server, claims, ctx := prepareTest(t, resourceType, client)
				request := &artifacts.GenerateSignedURLsRequest{
					Type: artifacts.GenerateSignedURLsRequest_YANK,
					Paths: []string{
						getPath(resourceType, claims, "first/file1.txt"),
						getPath(resourceType, claims, "first/file2.txt"),
					},
				}

				response, err := server.GenerateSignedURLs(ctx, request)
				require.Nil(t, err)
				require.Len(t, response.URLs, 1)
				assert.Equal(t, response.URLs[0].Method, artifacts.SignedURL_DELETE)
				assert.Contains(t, response.URLs[0].URL, getPath(resourceType, claims, "first/file1.txt"))
			})
		}
	})
}

func seedObjects(resourceType string, claims jwt.Claims) []storage.SeedObject {
	return []storage.SeedObject{
		{Name: getPath(resourceType, claims, "first/file1.txt"), Content: "first folder, first file"},
		{Name: getPath(resourceType, claims, "first/file2.txt"), Content: "first folder, second file"},
		{Name: getPath(resourceType, claims, "second/file1.txt"), Content: "second folder, first file"},
		{Name: getPath(resourceType, claims, "second/file2.txt"), Content: "second folder, second file"},
		{Name: getPath(resourceType, claims, "third/file1.txt"), Content: "third folder, first file"},
		{Name: getPath(resourceType, claims, "third/file2.txt"), Content: "third folder, second file"},
	}
}

func Test__GrpcServer(t *testing.T) {
	models.PrepareDatabaseForTests()

	storageClient, err := storage.NewGcsClient("")
	assert.Nil(t, err)

	server, claims, incomingCtx := prepareTest(t, ResourceTypeProjects, storageClient)

	bufSize := 1024 * 50
	lis := bufconn.Listen(bufSize)
	defer lis.Close()
	bufDialer := func(context.Context, string) (net.Conn, error) {
		return lis.Dial()
	}

	maxMsgSize := 1024
	os.Setenv("MAX_PUBLIC_RECEIVE_MSG_SIZE", strconv.Itoa(maxMsgSize))
	defer os.Unsetenv("MAX_PUBLIC_RECEIVE_MSG_SIZE")

	server.Port = 50334
	server.recoveryHandler = func(p interface{}) (err error) {
		return status.Errorf(codes.Internal, "panic triggered: %v", p)
	}

	go func() {
		server.serveWithListener(lis)
	}()
	time.Sleep(1 * time.Second)

	conn, err := grpc.DialContext(context.TODO(), "bufnet", grpc.WithContextDialer(bufDialer), grpc.WithInsecure())
	if err != nil {
		t.Fatalf("failed to dial bufnet: %v", err)
	}
	defer conn.Close()

	client := artifacts.NewArtifactsServiceClient(conn)

	// test sending a message smaller than max message size limit
	req := &artifacts.GenerateSignedURLsRequest{
		Type:  artifacts.GenerateSignedURLsRequest_PULL,
		Paths: []string{getPath(ResourceTypeProjects, claims, "first/file1.txt")},
	}

	meta, ok := metadata.FromIncomingContext(incomingCtx)
	assert.True(t, ok)

	ctxWithToken := metadata.NewOutgoingContext(context.TODO(), meta)
	_, err = client.GenerateSignedURLs(ctxWithToken, req)
	assert.NoError(t, err)

	// test sending a message larger than max message size limit
	var largePath strings.Builder
	for largePath.Len() <= maxMsgSize {
		largePath.WriteString("a")
	}
	req = &artifacts.GenerateSignedURLsRequest{
		Type:  artifacts.GenerateSignedURLsRequest_PULL,
		Paths: []string{getPath(ResourceTypeProjects, claims, largePath.String())},
	}

	_, err = client.GenerateSignedURLs(ctxWithToken, req)
	assert.Error(t, err)

	st, ok := status.FromError(err)
	assert.True(t, ok)
	assert.Equal(t, codes.ResourceExhausted, st.Code())
	assert.Contains(t, st.Message(), "received message larger than max")
}

func getPath(resourceType string, claims jwt.Claims, path string) string {
	switch resourceType {
	case ResourceTypeProjects:
		return fmt.Sprintf("artifacts/%s/%s/%s", ResourceTypeProjects, claims.Project, path)
	case ResourceTypeWorkflows:
		return fmt.Sprintf("artifacts/%s/%s/%s", ResourceTypeWorkflows, claims.Workflow, path)
	case ResourceTypeJobs:
		return fmt.Sprintf("artifacts/%s/%s/%s", ResourceTypeJobs, claims.Job, path)
	default:
		return ""
	}
}

func prepareTestWithClaims(t *testing.T, resourceType string, client storage.Client, claims jwt.Claims) (*Server, jwt.Claims, context.Context) {
	models.PrepareDatabaseForTests()

	bucketName, err := client.CreateBucket(context.TODO())
	require.NoError(t, err)

	artifact, err := models.CreateArtifact(bucketName, "idempotency-token")
	require.NoError(t, err)

	server := &Server{StorageClient: client, jwtSecret: JWTSecret}
	claims.ArtifactID = artifact.ID.String()
	options := storage.BucketOptions{
		Name:       artifact.BucketName,
		PathPrefix: artifact.IdempotencyToken,
	}

	err = storage.SeedBucket(client.GetBucket(options), seedObjects(resourceType, claims))
	require.NoError(t, err)

	ctx := prepareAuth(t, claims)
	return server, claims, ctx
}

func prepareTest(t *testing.T, resourceType string, client storage.Client) (*Server, jwt.Claims, context.Context) {
	baseClaims := jwt.Claims{
		Project:  uuid.NewV4().String(),
		Workflow: uuid.NewV4().String(),
		Job:      uuid.NewV4().String(),
	}

	return prepareTestWithClaims(t, resourceType, client, baseClaims)
}

func prepareAuth(t *testing.T, claims jwt.Claims) context.Context {
	token, err := jwt.GenerateToken(JWTSecret, claims, time.Minute)
	require.NoError(t, err)

	return metadata.NewIncomingContext(context.Background(), metadata.MD{
		"authorization": []string{token},
	})
}
