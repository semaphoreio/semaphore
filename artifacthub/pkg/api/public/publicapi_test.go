package publicapi

import (
	"context"
	"errors"
	"fmt"
	"testing"

	"github.com/semaphoreio/semaphore/artifacthub/pkg/models"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/storage"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestGenerateSignedURLsList_RetryDoesNotDuplicateURLs(t *testing.T) {
	client := &fakeClient{
		bucket: &fakeBucket{
			isFile: false,
			isDir:  true,
			iterations: []fakeIteration{
				{
					items:  []string{"artifacts/projects/first/file1.txt", "artifacts/projects/first/file2.txt"},
					failAt: 1,
				},
				{
					items:  []string{"artifacts/projects/first/file1.txt", "artifacts/projects/first/file2.txt"},
					failAt: -1,
				},
			},
		},
	}

	artifact := &models.Artifact{
		BucketName:       "test-bucket",
		IdempotencyToken: "request-token-1",
	}

	urls, err := GenerateSignedURLsList(context.Background(), client, artifact, "artifacts/projects/first/", "GET", 100)
	require.NoError(t, err)
	require.Len(t, urls, 2)

	assert.Contains(t, urls[0].URL, "artifacts/projects/first/file1.txt")
	assert.Contains(t, urls[1].URL, "artifacts/projects/first/file2.txt")
}

func TestGenerateSignedURLsList_ReturnsLimitError(t *testing.T) {
	client := &fakeClient{
		bucket: &fakeBucket{
			isFile: false,
			isDir:  true,
			iterations: []fakeIteration{
				{
					items: []string{
						"artifacts/projects/first/file1.txt",
						"artifacts/projects/first/file2.txt",
						"artifacts/projects/first/file3.txt",
					},
					failAt: -1,
				},
			},
		},
	}

	artifact := &models.Artifact{
		BucketName:       "test-bucket",
		IdempotencyToken: "request-token-1",
	}

	_, err := GenerateSignedURLsList(context.Background(), client, artifact, "artifacts/projects/first/", "GET", 2)
	require.Error(t, err)
	assert.ErrorIs(t, err, ErrTooManyArtifacts)
}

type fakeClient struct {
	bucket *fakeBucket
}

func (c *fakeClient) GetBucket(_ storage.BucketOptions) storage.Bucket {
	return c.bucket
}

func (c *fakeClient) CreateBucket(_ context.Context) (string, error) {
	return "", nil
}

func (c *fakeClient) DestroyBucket(_ context.Context, _ storage.BucketOptions) error {
	return nil
}

func (c *fakeClient) SignURL(_ context.Context, options storage.SignURLOptions) (string, error) {
	return fmt.Sprintf("https://example.com/%s", options.Path), nil
}

type fakeBucket struct {
	isFile     bool
	isDir      bool
	iterations []fakeIteration
	listCalls  int
}

func (b *fakeBucket) ListPath(_ storage.ListOptions) (storage.PathIterator, error) {
	idx := b.listCalls
	b.listCalls++

	if idx >= len(b.iterations) {
		return &fakePathIterator{items: []string{}, failAt: -1}, nil
	}

	iteration := b.iterations[idx]
	return &fakePathIterator{items: iteration.items, failAt: iteration.failAt}, nil
}

func (b *fakeBucket) ListObjectsWithPagination(_ storage.ListOptions) (storage.ObjectPager, error) {
	return nil, nil
}

func (b *fakeBucket) DeleteObjects(_ []string) error {
	return nil
}

func (b *fakeBucket) CreateObject(_ context.Context, _ string, _ []byte) error {
	return nil
}

func (b *fakeBucket) IsDir(_ context.Context, _ string) (bool, error) {
	return b.isDir, nil
}

func (b *fakeBucket) IsFile(_ context.Context, _ string) (bool, error) {
	return b.isFile, nil
}

func (b *fakeBucket) DeletePath(_ context.Context, _ string) error {
	return nil
}

func (b *fakeBucket) DeleteDir(_ context.Context, _ string) error {
	return nil
}

func (b *fakeBucket) DeleteFile(_ context.Context, _ string) error {
	return nil
}

func (b *fakeBucket) SetCORS(_ context.Context) error {
	return nil
}

func (b *fakeBucket) Destroy(_ context.Context) error {
	return nil
}

type fakeIteration struct {
	items  []string
	failAt int
}

type fakePathIterator struct {
	items  []string
	failAt int
	idx    int
	done   bool
}

func (i *fakePathIterator) Next() (*storage.PathItem, error) {
	if i.failAt >= 0 && i.idx == i.failAt {
		return nil, errors.New("transient list failure")
	}

	if i.idx >= len(i.items) {
		i.done = true
		return nil, storage.ErrNoMoreObjects
	}

	item := &storage.PathItem{
		Path:        i.items[i.idx],
		IsDirectory: false,
		Size:        1,
	}
	i.idx++

	return item, nil
}

func (i *fakePathIterator) Count() (int, error) {
	return len(i.items), nil
}

func (i *fakePathIterator) Done() bool {
	return i.done
}
