package storage

import (
	"context"
	"errors"
	"io"
	"io/ioutil"
	"log"
	"os"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsConfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/feature/s3/manager"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/smithy-go"
	"github.com/renderedtext/go-watchman"
)

type S3Storage struct {
	Client *s3.Client
	Bucket string
}

type S3StorageOptions struct {
	URL             string
	Bucket          string
	AccessKeyID     string
	SecretAccessKey string
	Region          string
}

func NewS3Storage(options S3StorageOptions) (*S3Storage, error) {
	if options.URL != "" {
		return createS3StorageUsingEndpoint(options)
	}

	return createDefaultS3Storage(options.Bucket)
}

func createDefaultS3Storage(s3Bucket string) (*S3Storage, error) {
	config, err := awsConfig.LoadDefaultConfig(context.TODO())
	if err != nil {
		return nil, err
	}

	log.Printf("Configuring default S3 storage client with following config: %v", config)

	return &S3Storage{
		Client: s3.NewFromConfig(config),
		Bucket: s3Bucket,
	}, nil
}

func createS3StorageUsingEndpoint(options S3StorageOptions) (*S3Storage, error) {
	resolver := aws.EndpointResolverFunc(func(service, region string) (aws.Endpoint, error) {
		return aws.Endpoint{
			URL: options.URL,
		}, nil
	})

	accessKeyId := "minioadmin"
	if options.AccessKeyID != "" {
		accessKeyId = options.AccessKeyID
	}
	secretAccessKey := "minioadmin"
	if options.SecretAccessKey != "" {
		secretAccessKey = options.SecretAccessKey
	}

	creds := credentials.NewStaticCredentialsProvider(accessKeyId, secretAccessKey, "")
	cfg, err := awsConfig.LoadDefaultConfig(context.TODO(),
		awsConfig.WithCredentialsProvider(creds),
		awsConfig.WithEndpointResolver(resolver),
	)

	if err != nil {
		return nil, err
	}

	svc := s3.NewFromConfig(cfg, func(o *s3.Options) {
		o.UsePathStyle = true
	})

	return &S3Storage{
		Client: svc,
		Bucket: options.Bucket,
	}, nil
}

// for testing only
func (s *S3Storage) CreateBucket(bucketName string) error {
	_, err := s.Client.CreateBucket(context.TODO(), &s3.CreateBucketInput{Bucket: &bucketName})
	return err
}

// for testing only
func (s *S3Storage) DeleteBucket(bucketName string) error {
	response, err := s.Client.ListObjectsV2(context.TODO(), &s3.ListObjectsV2Input{Bucket: &bucketName})
	if err != nil {
		return err
	}

	if err := s.deleteObjectsInBucket(bucketName, response); err != nil {
		return err
	}

	_, err = s.Client.DeleteBucket(context.TODO(), &s3.DeleteBucketInput{Bucket: &bucketName})
	return err
}

// for testing only
func (s *S3Storage) deleteObjectsInBucket(bucketName string, listResult *s3.ListObjectsV2Output) error {
	for _, object := range listResult.Contents {
		input := s3.DeleteObjectInput{Bucket: &bucketName, Key: object.Key}
		_, err := s.Client.DeleteObject(context.TODO(), &input)
		if err != nil {
			return err
		}
	}
	return nil
}

func (s *S3Storage) SaveFile(ctx context.Context, fileName, path string) error {
	defer watchman.Benchmark(time.Now(), "s3.write")

	// #nosec
	file, err := os.Open(fileName)
	if err != nil {
		return err
	}

	defer file.Close()

	log.Printf("Uploading to %s from %s", path, fileName)

	uploader := manager.NewUploader(s.Client)
	_, err = uploader.Upload(ctx, &s3.PutObjectInput{
		Bucket: &s.Bucket,
		Key:    &path,
		Body:   file,
	})

	log.Printf("Error %s", err)
	return err
}

func (s *S3Storage) Exists(ctx context.Context, fileName string) (bool, error) {
	input := s3.HeadObjectInput{
		Bucket: &s.Bucket,
		Key:    &fileName,
	}

	_, err := s.Client.HeadObject(ctx, &input)
	if err != nil {
		var apiErr *smithy.GenericAPIError
		if errors.As(err, &apiErr) && apiErr.ErrorCode() == "NotFound" {
			return false, nil
		}

		return false, err
	}

	return true, nil
}

func (s *S3Storage) ReadFile(ctx context.Context, fileName string) ([]byte, error) {
	defer watchman.Benchmark(time.Now(), "s3.read")

	response, err := s.Client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: &s.Bucket,
		Key:    &fileName,
	})

	if err != nil {
		return nil, err
	}

	defer response.Body.Close()
	compressed, err := ioutil.ReadAll(response.Body)
	if err != nil {
		return nil, err
	}

	return compressed, nil
}

// Note: the caller must close the returned reader.
func (s *S3Storage) ReadFileAsReader(ctx context.Context, fileName string) (io.ReadCloser, error) {
	defer watchman.Benchmark(time.Now(), "s3.read")

	response, err := s.Client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: &s.Bucket,
		Key:    &fileName,
	})

	if err != nil {
		return nil, err
	}

	return response.Body, nil
}

func (s *S3Storage) DeleteFile(ctx context.Context, fileName string) error {
	defer watchman.Benchmark(time.Now(), "s3.delete")

	log.Printf("Deleting %s from S3 bucket %s", fileName, s.Bucket)

	input := &s3.DeleteObjectInput{
		Bucket: &s.Bucket,
		Key:    &fileName,
	}

	_, err := s.Client.DeleteObject(ctx, input)
	if err != nil {
		var apiErr smithy.APIError
		if errors.As(err, &apiErr) && apiErr.ErrorCode() == "NoSuchKey" {
			log.Printf("File %s does not exist in S3 - treating as success", fileName)
			return nil
		}
		return err
	}

	log.Printf("Successfully deleted %s from S3", fileName)
	return nil
}
