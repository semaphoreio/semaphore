package storage

import (
	"context"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"net/url"
	"os"
	"time"

	gcs "cloud.google.com/go/storage"
	"github.com/renderedtext/go-watchman"
	"google.golang.org/api/iterator"
	"google.golang.org/api/option"
)

type RoundTripper url.URL

func (rt RoundTripper) RoundTrip(req *http.Request) (*http.Response, error) {
	req.Host = rt.Host
	req.URL.Host = rt.Host
	req.URL.Scheme = rt.Scheme
	return http.DefaultTransport.RoundTrip(req)
}

type GCSStorage struct {
	Client *gcs.Client
	Bucket string
}

func NewGCSStorageWithClient(httpClient *http.Client, bucketName string) (*GCSStorage, error) {
	client, err := gcs.NewClient(context.Background(), option.WithHTTPClient(httpClient))
	if err != nil {
		return nil, err
	}

	return &GCSStorage{client, bucketName}, nil
}

func NewGCSStorage(credsFile string, bucketName string) (*GCSStorage, error) {
	log.Printf("Creating gcs client from credentials loaded from %s", credsFile)

	client, err := gcs.NewClient(context.Background(), option.WithCredentialsFile(credsFile))
	if err != nil {
		return nil, err
	}

	return &GCSStorage{client, bucketName}, nil
}

func (s *GCSStorage) CreateBucket(bucketName string, projectId string) error {
	return s.Client.Bucket(bucketName).Create(context.Background(), projectId, nil)
}

func (s *GCSStorage) DeleteBucket(bucketName string) error {
	bucket := s.Client.Bucket(bucketName)
	if err := s.deleteObjectsInBucket(bucket); err != nil {
		return err
	}

	return bucket.Delete(context.Background())
}

func (s *GCSStorage) deleteObjectsInBucket(bucket *gcs.BucketHandle) error {
	ctx := context.Background()
	it := bucket.Objects(ctx, nil)

	for {
		objAttrs, err := it.Next()
		if err != nil && err != iterator.Done {
			return err
		}

		if err == iterator.Done {
			return nil
		}

		if err := bucket.Object(objAttrs.Name).Delete(ctx); err != nil {
			return err
		}
	}
}

func (s *GCSStorage) SaveFile(ctx context.Context, localFileName, gcsFileName string) error {
	defer watchman.Benchmark(time.Now(), "gcs.write")

	// #nosec
	file, err := os.Open(localFileName)
	if err != nil {
		return err
	}

	log.Printf("Uploading to %s from %s", gcsFileName, localFileName)

	w := s.Client.Bucket(s.Bucket).
		Object(gcsFileName).
		NewWriter(ctx)

	if _, err := io.Copy(w, file); err != nil {
		_ = file.Close()
		return err
	}

	if err := w.Close(); err != nil {
		_ = file.Close()
		return err
	}

	return file.Close()
}

func (s *GCSStorage) Exists(ctx context.Context, fileName string) (bool, error) {
	_, err := s.Client.Bucket(s.Bucket).
		Object(fileName).
		Attrs(ctx)
	return err == nil, err
}

func (s *GCSStorage) ReadFile(ctx context.Context, fileName string) ([]byte, error) {
	defer watchman.Benchmark(time.Now(), "gcs.read")

	reader, err := s.Client.Bucket(s.Bucket).
		Object(fileName).
		NewReader(ctx)
	if err != nil {
		return nil, err
	}

	defer reader.Close()
	compressed, err := ioutil.ReadAll(reader)
	if err != nil {
		return nil, err
	}

	return compressed, nil
}

func (s *GCSStorage) ReadFileAsReader(ctx context.Context, fileName string) (io.ReadCloser, error) {
	defer watchman.Benchmark(time.Now(), "gcs.read")

	reader, err := s.Client.Bucket(s.Bucket).
		Object(fileName).
		NewReader(ctx)
	if err != nil {
		return nil, err
	}

	return reader, nil
}

func (s *GCSStorage) DeleteFile(ctx context.Context, fileName string) error {
	defer watchman.Benchmark(time.Now(), "gcs.delete")

	return s.Client.Bucket(s.Bucket).Object(fileName).Delete(ctx)
}
