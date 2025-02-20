package storage

import (
	"context"
	"fmt"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/credentials"
	"github.com/aws/aws-sdk-go/aws/request"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
)

type S3 struct {
	URL        string
	Client     *s3.S3
	BucketName string
}

type S3Options struct {
	URL             string
	BucketName      string
	AccessKeyID     string
	SecretAccessKey string
	Region          string
}

var _ Client = &S3{}

func NewS3Client(options S3Options) (*S3, error) {
	if options.URL != "" {
		return createS3ClientUsingEndpoint(options)
	}

	return createDefaultS3Storage(options.BucketName)
}

func createDefaultS3Storage(bucketName string) (*S3, error) {
	session, err := session.NewSession()
	if err != nil {
		return nil, err
	}

	s3Client := s3.New(session)

	return &S3{
		Client:     s3Client,
		BucketName: bucketName,
	}, nil
}

func createS3ClientUsingEndpoint(options S3Options) (*S3, error) {
	config := s3OptionsToConfig(options)

	session, err := session.NewSession(config)

	if err != nil {
		return nil, err
	}

	s3Client := s3.New(session)

	return &S3{
		Client:     s3Client,
		BucketName: options.BucketName,
	}, nil
}

func s3OptionsToConfig(options S3Options) *aws.Config {
	if options.Region == "" {
		options.Region = "default"
	}
	if options.AccessKeyID == "" {
		options.AccessKeyID = "minioadmin"
	}
	if options.SecretAccessKey == "" {
		options.SecretAccessKey = "minioadmin"
	}
	return &aws.Config{
		Credentials:      credentials.NewStaticCredentials(options.AccessKeyID, options.SecretAccessKey, ""),
		Endpoint:         aws.String(options.URL),
		Region:           aws.String(options.Region),
		DisableSSL:       aws.Bool(true),
		S3ForcePathStyle: aws.Bool(true),
	}
}

// S3 storage uses a single bucket,
// so we ignore the bucket name passed as parameter here.
func (c *S3) GetBucket(options BucketOptions) Bucket {
	return &S3Bucket{
		BucketName: c.BucketName,
		Client:     c.Client,
		PathPrefix: options.PathPrefix,
	}
}

// S3 storage uses a single bucket, we don't create anything.
func (c *S3) CreateBucket(ctx context.Context) (string, error) {
	return c.BucketName, nil
}

// We do not delete the bucket, we only empty it
func (c *S3) DestroyBucket(ctx context.Context, options BucketOptions) error {
	bucket := c.GetBucket(options)
	return bucket.DeleteDir(ctx, "")
}

func (c *S3) SignURL(ctx context.Context, options SignURLOptions) (string, error) {
	request, err := c.buildSignURLRequest(options)
	if err != nil {
		return "", err
	}

	url, err := request.Presign(SignedURLExpireInMinutes * time.Minute)
	if err != nil {
		return "", err
	}

	return url, nil
}

func (c *S3) buildSignURLRequest(options SignURLOptions) (*request.Request, error) {
	path := options.Path
	if options.PathPrefix != "" {
		path = fmt.Sprintf("%s/%s", options.PathPrefix, options.Path)
	}

	switch options.Method {
	case "PUT":
		request, _ := c.Client.PutObjectRequest(&s3.PutObjectInput{
			Bucket: aws.String(options.BucketName),
			Key:    aws.String(path),
		})

		return request, nil
	case "GET":
		request, _ := c.Client.GetObjectRequest(&s3.GetObjectInput{
			Bucket: aws.String(options.BucketName),
			Key:    aws.String(path),
		})

		return request, nil
	case "HEAD":
		request, _ := c.Client.HeadObjectRequest(&s3.HeadObjectInput{
			Bucket: aws.String(options.BucketName),
			Key:    aws.String(path),
		})

		return request, nil
	case "DELETE":
		request, _ := c.Client.DeleteObjectRequest(&s3.DeleteObjectInput{
			Bucket: aws.String(options.BucketName),
			Key:    aws.String(path),
		})

		return request, nil
	default:
		return nil, fmt.Errorf("method %s not supported", options.Method)
	}
}
