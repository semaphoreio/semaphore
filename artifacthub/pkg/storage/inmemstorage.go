package storage

import (
	"context"
	"strconv"
	"time"
)

type InMemoryStorage struct {
	buckets map[string]Bucket
}

type InMemoryBucket struct {
	Name    string
	Objects []*PathItem
}

type InMemoryObjectIterator struct {
	bucket *InMemoryBucket
	index  int
}

type InMemoryObjectPager struct {
	bucket          *InMemoryBucket
	paginationToken int
}

const InMemoryStorageObjectPerPage = 100

var _ Client = &InMemoryStorage{}
var _ ObjectPager = &InMemoryObjectPager{}

func NewInMemoryStorage() *InMemoryStorage {
	return &InMemoryStorage{
		buckets: make(map[string]Bucket),
	}
}

func (c *InMemoryStorage) GetBucket(options BucketOptions) Bucket {
	name := options.Name
	if c.buckets[name] != nil {
		return c.buckets[name]
	}

	c.buckets[name] = &InMemoryBucket{Name: name, Objects: []*PathItem{}}
	return c.buckets[name]
}

func (b *InMemoryBucket) Size() int {
	counter := 0

	for _, el := range b.Objects {
		if el != nil {
			counter++
		}
	}

	return counter
}

func (b *InMemoryBucket) Add(path string, age time.Time) error {
	newAge := time.Since(age)
	b.Objects = append(b.Objects, &PathItem{Path: "artifacts" + path, Age: &newAge, Size: 1024}) // Default size for testing

	return nil
}

func (b *InMemoryBucket) ListPath(options ListOptions) (PathIterator, error) {
	return &InMemoryObjectIterator{bucket: b}, nil
}

func (b *InMemoryBucket) ListObjectsWithPagination(options ListOptions) (ObjectPager, error) {
	if options.PaginationToken == "" {
		return &InMemoryObjectPager{bucket: b, paginationToken: 0}, nil
	}

	token, err := strconv.Atoi(options.PaginationToken)
	if err != nil {
		return nil, err
	}

	return &InMemoryObjectPager{bucket: b, paginationToken: token}, nil
}

func (b *InMemoryBucket) DeleteObjects(paths []string) error {
	for i := 0; i < len(b.Objects); i++ {
		if b.Objects[i] == nil {
			continue
		}

		remove := false

		for _, p := range paths {
			if b.Objects[i].Path == p {
				remove = true
				break
			}
		}

		if remove {
			b.Objects[i] = nil
		}
	}

	return nil
}

func (p *InMemoryObjectPager) NextPage() ([]*Object, string, error) {
	result := []*Object{}

	for i := p.paginationToken; i < len(p.bucket.Objects) && len(result) <= InMemoryStorageObjectPerPage; i++ {
		p.paginationToken++
		if p.bucket.Objects[i] == nil {
			continue
		}

		result = append(result, &Object{
			Path: p.bucket.Objects[i].Path,
			Age:  p.bucket.Objects[i].Age,
		})
	}

	if p.paginationToken == len(p.bucket.Objects) {
		return result, "", nil
	}

	return result, strconv.Itoa(p.paginationToken), nil
}

func (i *InMemoryObjectIterator) Next() (*PathItem, error) {
	if i.Done() {
		return nil, ErrNoMoreObjects
	}

	res := &i.bucket.Objects[i.index]
	i.index++

	return *res, nil
}

func (i *InMemoryObjectIterator) Done() bool {
	return i.index >= len(i.bucket.Objects)
}

func (i *InMemoryObjectIterator) Count() (int, error) {
	return 0, nil
}

func (p *InMemoryObjectPager) Count() (int, error) {
	return 0, nil
}

func (c *InMemoryStorage) CreateBucket(ctx context.Context) (string, error) {
	return "", nil
}

func (c *InMemoryStorage) DestroyBucket(ctx context.Context, options BucketOptions) error {
	return nil
}

func (c *InMemoryStorage) SignURL(ctx context.Context, options SignURLOptions) (string, error) {
	return "", nil
}

func (b *InMemoryBucket) Destroy(ctx context.Context) error {
	return nil
}

func (b *InMemoryBucket) IsDir(ctx context.Context, dir string) (bool, error) {
	return false, nil
}

func (b *InMemoryBucket) IsFile(ctx context.Context, path string) (bool, error) {
	return false, nil
}

func (b *InMemoryBucket) DeleteDir(ctx context.Context, dir string) error {
	return nil
}

func (b *InMemoryBucket) DeleteFile(ctx context.Context, path string) error {
	return nil
}

func (b *InMemoryBucket) DeletePath(ctx context.Context, path string) error {
	return nil
}

func (b *InMemoryBucket) SetCORS(ctx context.Context) error {
	return nil
}

func (b *InMemoryBucket) CreateObject(ctx context.Context, name string, content []byte) error {
	b.Objects = append(b.Objects, &PathItem{
		Path:        name,
		IsDirectory: false,
		Age:         nil,
		Size:        int64(len(content)),
	})
	return nil
}
