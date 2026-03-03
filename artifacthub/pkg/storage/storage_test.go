package storage

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
)

const TestBucketPathPrefix = "test-prefix"

func Test__CreateAndDestroyBucket(t *testing.T) {
	RunTestForAllBackends(t, func(backend string, client Client) {
		t.Run(backend, func(t *testing.T) {
			bucketName, err := client.CreateBucket(context.TODO())
			assert.Nil(t, err)
			assert.NotEmpty(t, bucketName)
			assert.Nil(t, client.DestroyBucket(context.TODO(), BucketOptions{
				Name:       bucketName,
				PathPrefix: TestBucketPathPrefix,
			}))
		})
	})
}

func Test__ListPath(t *testing.T) {
	RunTestForAllBackends(t, func(backend string, client Client) {
		bucketName, err := client.CreateBucket(context.TODO())
		assert.Nil(t, err)

		bucket := client.GetBucket(BucketOptions{
			Name:       bucketName,
			PathPrefix: TestBucketPathPrefix,
		})

		assert.Nil(t, SeedBucket(bucket, seedObjects()))

		t.Run(backend+" listing without max keys", func(t *testing.T) {
			iterator, err := bucket.ListPath(ListOptions{Path: "artifacts/"})
			assert.Nil(t, err)
			assertIterator(t, iterator, false)
		})

		t.Run(backend+" listing with max keys", func(t *testing.T) {
			iterator, err := bucket.ListPath(ListOptions{Path: "artifacts/", MaxKeys: 3})
			assert.Nil(t, err)
			assertIterator(t, iterator, false)
		})

		t.Run(backend+" wrap sub directories", func(t *testing.T) {
			iterator, err := bucket.ListPath(ListOptions{Path: "artifacts/", WrapSubDirectories: true})
			assert.Nil(t, err)
			assertIterator(t, iterator, true)
		})

		t.Run(backend+" wrap sub directories with max keys", func(t *testing.T) {
			iterator, err := bucket.ListPath(ListOptions{Path: "artifacts/first/", MaxKeys: 2, WrapSubDirectories: true})
			assert.Nil(t, err)

			objects := collectItems(iterator)
			if assert.Len(t, objects, 3) {
				assert.Equal(t, objects[0].Path, "artifacts/first/file1.txt")
				assert.False(t, objects[0].IsDirectory)
				assert.Equal(t, objects[1].Path, "artifacts/first/file2.txt")
				assert.False(t, objects[1].IsDirectory)
				assert.Equal(t, objects[2].Path, "artifacts/first/somedir/")
				assert.True(t, objects[2].IsDirectory)
			}
		})

		assert.Nil(t, client.DestroyBucket(context.TODO(), BucketOptions{
			Name:       bucketName,
			PathPrefix: TestBucketPathPrefix,
		}))
	})
}

func Test__ListObjectsWithPagination(t *testing.T) {
	RunTestForAllBackends(t, func(backend string, client Client) {
		bucketName, err := client.CreateBucket(context.TODO())
		assert.Nil(t, err)

		bucket := client.GetBucket(BucketOptions{
			Name:       bucketName,
			PathPrefix: TestBucketPathPrefix,
		})

		assert.Nil(t, SeedBucket(bucket, seedObjects()))

		t.Run(backend+" listing without max keys", func(t *testing.T) {
			pager, err := bucket.ListObjectsWithPagination(ListOptions{Path: "artifacts/"})
			assert.Nil(t, err)

			objects, nextToken, err := pager.NextPage()
			if !assert.Nil(t, err) {
				return
			}

			assert.Empty(t, nextToken)
			if assert.Len(t, objects, 7) {
				assert.Equal(t, objects[0].Path, "artifacts/first/file1.txt")
				assert.Equal(t, objects[1].Path, "artifacts/first/file2.txt")
				assert.Equal(t, objects[2].Path, "artifacts/first/somedir/file3.txt")
				assert.Equal(t, objects[3].Path, "artifacts/second/file1.txt")
				assert.Equal(t, objects[4].Path, "artifacts/second/file2.txt")
				assert.Equal(t, objects[5].Path, "artifacts/third/file1.txt")
				assert.Equal(t, objects[6].Path, "artifacts/third/file2.txt")
			}
		})

		t.Run(backend+" listing with max keys", func(t *testing.T) {
			if backend == "gcs" {
				t.Skip("fake-gcs-server doesn't support maxResults and pageToken")
			}

			pager, err := bucket.ListObjectsWithPagination(ListOptions{Path: "artifacts/", MaxKeys: 3})
			assert.Nil(t, err)

			// We have 7 objects in storage, and we are building pages with 3 objects,
			// so we should get 3 pages of sizes 3, 3, 1
			firstPage, nextToken, err := pager.NextPage()
			if !assert.Nil(t, err) {
				return
			}

			assert.NotEmpty(t, nextToken)
			if assert.Len(t, firstPage, 3) {
				assert.Equal(t, firstPage[0].Path, "artifacts/first/file1.txt")
				assert.Equal(t, firstPage[1].Path, "artifacts/first/file2.txt")
				assert.Equal(t, firstPage[2].Path, "artifacts/first/somedir/file3.txt")
			}

			secondPage, nextToken, err := pager.NextPage()
			if !assert.Nil(t, err) {
				return
			}

			assert.NotEmpty(t, nextToken)
			if assert.Len(t, secondPage, 3) {
				assert.Equal(t, secondPage[0].Path, "artifacts/second/file1.txt")
				assert.Equal(t, secondPage[1].Path, "artifacts/second/file2.txt")
				assert.Equal(t, secondPage[2].Path, "artifacts/third/file1.txt")
			}

			thirdPage, nextToken, err := pager.NextPage()
			if !assert.Nil(t, err) {
				return
			}

			assert.Empty(t, nextToken)
			if assert.Len(t, thirdPage, 1) {
				assert.Equal(t, thirdPage[0].Path, "artifacts/third/file2.txt")
			}
		})

		assert.Nil(t, client.DestroyBucket(context.TODO(), BucketOptions{
			Name:       bucketName,
			PathPrefix: TestBucketPathPrefix,
		}))
	})
}

func Test__IsFile(t *testing.T) {
	RunTestForAllBackends(t, func(backend string, client Client) {
		bucketName, err := client.CreateBucket(context.TODO())
		assert.Nil(t, err)

		bucket := client.GetBucket(BucketOptions{
			Name:       bucketName,
			PathPrefix: TestBucketPathPrefix,
		})

		assert.Nil(t, SeedBucket(bucket, seedObjects()))

		t.Run(backend+" file exists => true", func(t *testing.T) {
			isFile, err := bucket.IsFile(context.Background(), "artifacts/first/file1.txt")
			assert.Nil(t, err)
			assert.True(t, isFile)
		})

		t.Run(backend+" file does not exist => false", func(t *testing.T) {
			isFile, err := bucket.IsFile(context.Background(), "artifacts/no/such/path/file.txt")
			assert.Nil(t, err)
			assert.False(t, isFile)
		})

		t.Run(backend+" existing directory => false", func(t *testing.T) {
			isFile, err := bucket.IsFile(context.Background(), "artifacts/first")
			assert.Nil(t, err)
			assert.False(t, isFile)
		})

		assert.Nil(t, client.DestroyBucket(context.TODO(), BucketOptions{
			Name:       bucketName,
			PathPrefix: TestBucketPathPrefix,
		}))
	})
}

func Test__IsDir(t *testing.T) {
	RunTestForAllBackends(t, func(backend string, client Client) {
		bucketName, err := client.CreateBucket(context.TODO())
		assert.Nil(t, err)

		bucket := client.GetBucket(BucketOptions{
			Name:       bucketName,
			PathPrefix: TestBucketPathPrefix,
		})

		assert.Nil(t, SeedBucket(bucket, seedObjects()))

		t.Run(backend+" directory exists => true", func(t *testing.T) {
			isDir, err := bucket.IsDir(context.Background(), "artifacts/")
			assert.Nil(t, err)
			assert.True(t, isDir)
		})

		t.Run(backend+" directory with missing slash exists => true", func(t *testing.T) {
			isDir, err := bucket.IsDir(context.Background(), "artifacts")
			assert.Nil(t, err)
			assert.True(t, isDir)
		})

		t.Run(backend+" sub-directories exist => true", func(t *testing.T) {
			isDir, err := bucket.IsDir(context.Background(), "artifacts/first")
			assert.Nil(t, err)
			assert.True(t, isDir)

			isDir, err = bucket.IsDir(context.Background(), "artifacts/second")
			assert.Nil(t, err)
			assert.True(t, isDir)

			isDir, err = bucket.IsDir(context.Background(), "artifacts/third")
			assert.Nil(t, err)
			assert.True(t, isDir)
		})

		t.Run(backend+" directory does not exist => false", func(t *testing.T) {
			isDir, err := bucket.IsDir(context.Background(), "artifacts/this-does-not-exist")
			assert.Nil(t, err)
			assert.False(t, isDir)
		})

		t.Run(backend+" existing file => false", func(t *testing.T) {
			isDir, err := bucket.IsDir(context.Background(), "artifacts/first/file1.txt")
			assert.Nil(t, err)
			assert.False(t, isDir)
		})

		assert.Nil(t, client.DestroyBucket(context.TODO(), BucketOptions{
			Name:       bucketName,
			PathPrefix: TestBucketPathPrefix,
		}))
	})
}

func Test__DeleteFile(t *testing.T) {
	RunTestForAllBackends(t, func(backend string, client Client) {
		bucketName, err := client.CreateBucket(context.TODO())
		assert.Nil(t, err)

		bucket := client.GetBucket(BucketOptions{
			Name:       bucketName,
			PathPrefix: TestBucketPathPrefix,
		})

		assert.Nil(t, SeedBucket(bucket, seedObjects()))

		t.Run(backend+" deleting a non-existing file does not throw an error", func(t *testing.T) {
			file := "artifacts/non/existing/path/file.txt"

			// file does not exist before
			isFile, err := bucket.IsFile(context.Background(), file)
			assert.Nil(t, err)
			assert.False(t, isFile)

			// no error
			assert.Nil(t, bucket.DeleteFile(context.Background(), file))
		})

		t.Run(backend+" deletes existing file", func(t *testing.T) {
			// file exists before
			isFile, err := bucket.IsFile(context.Background(), "artifacts/first/file1.txt")
			assert.Nil(t, err)
			assert.True(t, isFile)

			// file is deleted
			assert.Nil(t, bucket.DeleteFile(context.Background(), "artifacts/first/file1.txt"))

			// file does not exist anymore
			isFile, err = bucket.IsFile(context.Background(), "artifacts/first/file1.txt")
			assert.Nil(t, err)
			assert.False(t, isFile)
		})

		t.Run(backend+" parent directory is not deleted", func(t *testing.T) {
			// file exists before
			isFile, err := bucket.IsFile(context.Background(), "artifacts/second/file1.txt")
			assert.Nil(t, err)
			assert.True(t, isFile)

			// file is deleted
			assert.Nil(t, bucket.DeleteFile(context.Background(), "artifacts/second/file1.txt"))

			// file does not exist
			IsFile, err := bucket.IsFile(context.Background(), "artifacts/second/file1.txt")
			assert.Nil(t, err)
			assert.False(t, IsFile)

			// parent directory still exists
			isDir, err := bucket.IsDir(context.Background(), "artifacts/second")
			assert.Nil(t, err)
			assert.True(t, isDir)
		})

		t.Run(backend+" directory cannot be deleted", func(t *testing.T) {
			// directory exists before
			isDir, err := bucket.IsDir(context.Background(), "artifacts/third")
			assert.Nil(t, err)
			assert.True(t, isDir)

			// directory is attempted to be deleted
			assert.Nil(t, bucket.DeleteFile(context.Background(), "artifacts/third"))

			// directory still exists
			isDir, err = bucket.IsDir(context.Background(), "artifacts/third")
			assert.Nil(t, err)
			assert.True(t, isDir)
		})

		assert.Nil(t, client.DestroyBucket(context.TODO(), BucketOptions{
			Name:       bucketName,
			PathPrefix: TestBucketPathPrefix,
		}))
	})
}

func Test__DeleteDir(t *testing.T) {
	RunTestForAllBackends(t, func(backend string, client Client) {
		bucketName, err := client.CreateBucket(context.TODO())
		assert.Nil(t, err)

		bucket := client.GetBucket(BucketOptions{
			Name:       bucketName,
			PathPrefix: TestBucketPathPrefix,
		})

		assert.Nil(t, SeedBucket(bucket, seedObjects()))

		t.Run(backend+" deleting a non-existing directory does not throw an error", func(t *testing.T) {
			dir := "artifacts/this-does-not-exist"

			// directory does not exist before
			isDir, err := bucket.IsDir(context.Background(), dir)
			assert.Nil(t, err)
			assert.False(t, isDir)

			// no error
			assert.Nil(t, bucket.DeleteDir(context.Background(), dir))
		})

		t.Run(backend+" deletes only single sub-directory", func(t *testing.T) {
			// directory exists before
			isDir, err := bucket.IsDir(context.Background(), "artifacts/first")
			assert.Nil(t, err)
			assert.True(t, isDir)

			// directory is deleted
			assert.Nil(t, bucket.DeleteDir(context.Background(), "artifacts/first"))

			// directory does not exist anymore
			isDir, err = bucket.IsDir(context.Background(), "artifacts/first")
			assert.Nil(t, err)
			assert.False(t, isDir)

			// root directory still exists
			isDir, err = bucket.IsDir(context.Background(), "artifacts/")
			assert.Nil(t, err)
			assert.True(t, isDir)
		})

		t.Run(backend+" deletes directory and sub-directories", func(t *testing.T) {
			// root and sub-directories exists before
			for _, dir := range []string{"artifacts/", "artifacts/second", "artifacts/third"} {
				isDir, err := bucket.IsDir(context.Background(), dir)
				assert.Nil(t, err)
				assert.True(t, isDir)
			}

			// root directory is deleted
			assert.Nil(t, bucket.DeleteDir(context.Background(), "artifacts/"))

			// root and sub-directories are gone
			for _, dir := range []string{"artifacts/", "artifacts/second", "artifacts/third"} {
				isDir, err := bucket.IsDir(context.Background(), dir)
				assert.Nil(t, err)
				assert.False(t, isDir)
			}
		})

		assert.Nil(t, client.DestroyBucket(context.TODO(), BucketOptions{
			Name:       bucketName,
			PathPrefix: TestBucketPathPrefix,
		}))
	})
}

func Test__DeletePath(t *testing.T) {
	RunTestForAllBackends(t, func(backend string, client Client) {
		bucketName, err := client.CreateBucket(context.TODO())
		assert.Nil(t, err)

		bucket := client.GetBucket(BucketOptions{
			Name:       bucketName,
			PathPrefix: TestBucketPathPrefix,
		})

		assert.Nil(t, SeedBucket(bucket, seedObjects()))

		t.Run(backend+" deleting a non-existing path does not throw an error", func(t *testing.T) {
			dir := "artifacts/this-does-not-exist"

			// directory does not exist before
			isDir, err := bucket.IsDir(context.Background(), dir)
			assert.Nil(t, err)
			assert.False(t, isDir)

			// no error
			assert.Nil(t, bucket.DeletePath(context.Background(), dir))
		})

		t.Run(backend+" deletes directory", func(t *testing.T) {
			// directory exists before
			isDir, err := bucket.IsDir(context.Background(), "artifacts/first")
			assert.Nil(t, err)
			assert.True(t, isDir)

			// directory is deleted
			assert.Nil(t, bucket.DeletePath(context.Background(), "artifacts/first"))

			// directory does not exist anymore
			isDir, err = bucket.IsDir(context.Background(), "artifacts/first")
			assert.Nil(t, err)
			assert.False(t, isDir)

			// root directory still exists
			isDir, err = bucket.IsDir(context.Background(), "artifacts/")
			assert.Nil(t, err)
			assert.True(t, isDir)
		})

		t.Run(backend+" deletes file", func(t *testing.T) {
			// file exists before
			isFile, err := bucket.IsFile(context.Background(), "artifacts/second/file2.txt")
			assert.Nil(t, err)
			assert.True(t, isFile)

			// file is deleted
			assert.Nil(t, bucket.DeletePath(context.Background(), "artifacts/second/file2.txt"))

			// directory does not exist anymore
			isFile, err = bucket.IsFile(context.Background(), "artifacts/second/file2.txt")
			assert.Nil(t, err)
			assert.False(t, isFile)

			// parent directory still exists
			isDir, err := bucket.IsDir(context.Background(), "artifacts/second")
			assert.Nil(t, err)
			assert.True(t, isDir)
		})

		assert.Nil(t, client.DestroyBucket(context.TODO(), BucketOptions{
			Name:       bucketName,
			PathPrefix: TestBucketPathPrefix,
		}))
	})
}

func collectItems(iterator PathIterator) []PathItem {
	objects := []PathItem{}
	for {
		object, err := iterator.Next()
		if err == ErrNoMoreObjects {
			break
		}

		objects = append(objects, *object)
	}

	return objects
}

func assertIterator(t *testing.T, iterator PathIterator, wrappedDirectories bool) {
	objects := collectItems(iterator)

	if wrappedDirectories {
		assert.Equal(t, []PathItem{
			{Path: "artifacts/first/", IsDirectory: true},
			{Path: "artifacts/second/", IsDirectory: true},
			{Path: "artifacts/third/", IsDirectory: true},
		}, objects)
	} else {
		if assert.Len(t, objects, 7) {
			assert.Equal(t, "artifacts/first/file1.txt", objects[0].Path)
			assert.False(t, objects[0].IsDirectory)
			assert.Equal(t, "artifacts/first/file2.txt", objects[1].Path)
			assert.False(t, objects[1].IsDirectory)
			assert.Equal(t, "artifacts/first/somedir/file3.txt", objects[2].Path)
			assert.False(t, objects[2].IsDirectory)
			assert.Equal(t, "artifacts/second/file1.txt", objects[3].Path)
			assert.False(t, objects[3].IsDirectory)
			assert.Equal(t, "artifacts/second/file2.txt", objects[4].Path)
			assert.False(t, objects[4].IsDirectory)
			assert.Equal(t, "artifacts/third/file1.txt", objects[5].Path)
			assert.False(t, objects[5].IsDirectory)
			assert.Equal(t, "artifacts/third/file2.txt", objects[6].Path)
			assert.False(t, objects[6].IsDirectory)
		}
	}
}

func seedObjects() []SeedObject {
	return []SeedObject{
		{Name: "artifacts/first/file1.txt", Content: "hello"},
		{Name: "artifacts/first/file2.txt", Content: "hello"},
		{Name: "artifacts/first/somedir/file3.txt", Content: "hello"},
		{Name: "artifacts/second/file1.txt", Content: "hello"},
		{Name: "artifacts/second/file2.txt", Content: "hello"},
		{Name: "artifacts/third/file2.txt", Content: "hello"},
		{Name: "artifacts/third/file1.txt", Content: "hello"},
	}
}

func Test__SpecialCharactersInPath(t *testing.T) {
	RunTestForAllBackends(t, func(backend string, client Client) {
		bucketName, err := client.CreateBucket(context.TODO())
		assert.Nil(t, err)

		bucket := client.GetBucket(BucketOptions{
			Name:       bucketName,
			PathPrefix: TestBucketPathPrefix,
		})

		t.Run(backend+" plus sign in filename", func(t *testing.T) {
			path := "artifacts/special/file+with+plus.txt"
			assert.Nil(t, SeedBucket(bucket, []SeedObject{
				{Name: path, Content: "content with plus"},
			}))

			isFile, err := bucket.IsFile(context.Background(), path)
			assert.Nil(t, err)
			assert.True(t, isFile)

			isDir, err := bucket.IsDir(context.Background(), "artifacts/special")
			assert.Nil(t, err)
			assert.True(t, isDir)

			iterator, err := bucket.ListPath(ListOptions{Path: "artifacts/special/"})
			assert.Nil(t, err)
			objects := collectItems(iterator)
			if assert.Len(t, objects, 1) {
				assert.Equal(t, path, objects[0].Path)
			}
		})

		assert.Nil(t, client.DestroyBucket(context.TODO(), BucketOptions{
			Name:       bucketName,
			PathPrefix: TestBucketPathPrefix,
		}))
	})
}
