package storage

import (
	"context"
	cryptoRand "crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"os"
	"strings"
	"time"

	gcsstorage "cloud.google.com/go/storage"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/util/log"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/util/random"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/util/retry"
	"go.uber.org/zap"
	"google.golang.org/api/option"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

const SignedURLExpireInMinutes = 20

var (
	cors = []gcsstorage.CORS{
		{
			MaxAge:          time.Hour,
			Methods:         []string{"GET", "HEAD"},
			Origins:         strings.Split(os.Getenv("CORS_ORIGINS"), ","),
			ResponseHeaders: []string{"Access-Control-Request-Header"},
		},
	}
)

// ServiceAccountCredentials is an object for
// parsing the Google Cloud Storage credentials from the JSON file.
type ServiceAccountCredentials struct {
	ProjectID   string `json:"project_id"`
	ClientEmail string `json:"client_email"`
	PrivateKey  string `json:"private_key"`
}

type Gcs struct {
	Client                  *gcsstorage.Client
	Credentials             ServiceAccountCredentials
	Mimes                   map[string]bool
	ExtraMimes              map[string]string
	ManageBucketPermissions bool
}

var _ Client = &Gcs{}

func NewGcsClient(credentialsFile string) (*Gcs, error) {
	if os.Getenv("STORAGE_EMULATOR_HOST") != "" {
		return newGcsClientForEmulator()
	}

	return newGcsClientWithAuthentication(credentialsFile)
}

func newGcsClientWithAuthentication(credentialsFile string) (*Gcs, error) {
	log.Debug("GCS credentials loaded from", zap.String("credFile", credentialsFile))

	// #nosec
	f, err := os.Open(credentialsFile)
	if err != nil {
		return nil, err
	}

	defer f.Close()

	var credentials ServiceAccountCredentials
	if err = json.NewDecoder(f).Decode(&credentials); err != nil {
		return nil, err
	}

	client, err := gcsstorage.NewClient(
		context.Background(),
		option.WithCredentialsFile(credentialsFile),
	)

	if err != nil {
		return nil, err
	}

	return &Gcs{
		Client:                  client,
		Credentials:             credentials,
		Mimes:                   LoadMimes(),
		ExtraMimes:              LoadExtraMimes(),
		ManageBucketPermissions: true,
	}, nil
}

func newGcsClientForEmulator() (*Gcs, error) {
	client, err := gcsstorage.NewClient(context.Background())
	if err != nil {
		return nil, err
	}

	// If we don't use a valid private key,
	// the URL signer complains
	privatekey, err := generatePrivateKey()
	if err != nil {
		return nil, err
	}

	credentials := ServiceAccountCredentials{
		ClientEmail: "testing@test.com",
		ProjectID:   "testing",
		PrivateKey:  privatekey,
	}

	return &Gcs{
		Client:                  client,
		Credentials:             credentials,
		Mimes:                   LoadMimes(),
		ExtraMimes:              LoadExtraMimes(),
		ManageBucketPermissions: false,
	}, nil
}

func generatePrivateKey() (string, error) {
	privateKey, err := rsa.GenerateKey(cryptoRand.Reader, 2048)
	if err != nil {
		return "", err
	}

	privateKeyAsPEM := pem.EncodeToMemory(
		&pem.Block{
			Type:  "RSA PRIVATE KEY",
			Bytes: x509.MarshalPKCS1PrivateKey(privateKey),
		},
	)

	return string(privateKeyAsPEM), nil
}

func (c *Gcs) GetBucket(options BucketOptions) Bucket {
	return &GcsBucket{
		BucketName:    options.Name,
		BucketHandler: c.Client.Bucket(options.Name),
	}
}

func (c *Gcs) createBucket(ctx context.Context) (string, error) {
	var randomBucketName string

	err := retry.OnFailure(ctx, "Bucket creation", func() error {
		// random name logs on its own, but it's necessary to be inside the block,
		// because it may happen to get a name that is already exist
		bucketName, err := random.RandomNameStr(ctx)
		if err != nil {
			return err
		}

		randomBucketName = bucketName
		bucket := c.Client.Bucket(randomBucketName)
		attrs := &gcsstorage.BucketAttrs{
			Location:     "europe-west3",
			StorageClass: "REGIONAL",
			CORS:         cors,
		}

		return bucket.Create(ctx, c.Credentials.ProjectID, attrs)
	})

	return randomBucketName, err
}

func (c *Gcs) CreateBucket(ctx context.Context) (string, error) {
	name, err := c.createBucket(ctx)
	if err != nil {
		return name, err
	}

	if !c.ManageBucketPermissions {
		return name, nil
	}

	bucket := c.GetBucket(BucketOptions{Name: name}).(*GcsBucket)
	err = bucket.AddUser(ctx, c.Credentials.ClientEmail)
	return name, err
}

func (c *Gcs) SignURL(ctx context.Context, options SignURLOptions) (string, error) {
	expires := time.Now().Add(time.Minute * SignedURLExpireInMinutes)
	url, err := gcsstorage.SignedURL(options.BucketName, options.Path, &gcsstorage.SignedURLOptions{
		GoogleAccessID: c.Credentials.ClientEmail,
		PrivateKey:     []byte(c.Credentials.PrivateKey),
		Method:         options.Method,
		Expires:        expires,
	})

	if err != nil {
		return "", err
	}

	if !options.IncludeContentType {
		return url, nil
	}

	return AppendContentType(c.Mimes, c.ExtraMimes, url, options.Path), nil
}

func (c *Gcs) DestroyBucket(ctx context.Context, options BucketOptions) error {
	// collect all errors, but tries to run all to leak as few as possible
	errs := []string{}

	bucket := c.GetBucket(options).(*GcsBucket)
	err := retry.OnFailure(ctx, "Deleting all objects in Bucket", func() error {
		return bucket.DeleteDir(ctx, "")
	})

	if err != nil {
		errs = append(errs, err.Error())
	}

	if c.ManageBucketPermissions {
		if err = bucket.RemoveUser(ctx, c.Credentials.ClientEmail); err != nil {
			errs = append(errs, err.Error())
		}
	}

	err = bucket.Destroy(ctx)
	if err != nil {
		errs = append(errs, err.Error())
	}

	if len(errs) == 0 {
		return nil
	}

	return status.Error(codes.Aborted,
		fmt.Sprintf("Found %d errors: %s", len(errs), strings.Join(errs, "; ")))
}
