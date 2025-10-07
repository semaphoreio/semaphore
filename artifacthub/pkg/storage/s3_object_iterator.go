package storage

import (
	"fmt"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go/service/s3"
)

type S3PathIterator struct {
	Client          *s3.S3
	LastOutput      *s3.ListObjectsOutput
	PathPrefix      string
	NextObjectIndex int
	NextPrefixIndex int
	IsDone          bool
}

var _ PathIterator = &S3PathIterator{}

func (i *S3PathIterator) Next() (*PathItem, error) {
	// If all the objects in the last response were already consumed,
	// and the last response was not truncated, there are no more objects to consume.
	if i.consumedAllFiles() && i.consumedAllPrefixes() && !*i.LastOutput.IsTruncated {
		i.IsDone = true
		return nil, ErrNoMoreObjects
	}

	// If all the objects in the last response were already consumed,
	// but the last response was truncated, we need to fetch more objects.
	if i.consumedAllFiles() && i.consumedAllPrefixes() && *i.LastOutput.IsTruncated {
		err := i.fetch()
		if err != nil {
			return nil, err
		}
	}

	// There are still objects in the last response that were not consumed
	return i.nextAndIncrement(), nil
}

func (i *S3PathIterator) consumedAllFiles() bool {
	return i.NextObjectIndex >= len(i.LastOutput.Contents)
}

func (i *S3PathIterator) consumedAllPrefixes() bool {
	return i.NextPrefixIndex >= len(i.LastOutput.CommonPrefixes)
}

func (i *S3PathIterator) fetch() error {
	output, err := i.Client.ListObjects(&s3.ListObjectsInput{
		Bucket:    i.LastOutput.Name,
		Prefix:    i.LastOutput.Prefix,
		MaxKeys:   i.LastOutput.MaxKeys,
		Delimiter: i.LastOutput.Delimiter,
		Marker:    i.findNextMarker(),
	})

	if err != nil {
		return err
	}

	if len(output.Contents) == 0 && len(output.CommonPrefixes) == 0 {
		i.IsDone = true
		return ErrNoMoreObjects
	}

	i.LastOutput = output
	i.NextObjectIndex = 0
	i.NextPrefixIndex = 0
	return nil
}

func (i *S3PathIterator) nextAndIncrement() *PathItem {
	if !i.consumedAllFiles() {
		next := i.LastOutput.Contents[i.NextObjectIndex]
		age := time.Since(*next.LastModified)
		i.NextObjectIndex++

		return &PathItem{
			Path:        i.removePathPrefix(*next.Key),
			IsDirectory: false,
			Age:         &age,
			Size:        *next.Size,
		}
	}

	nextPrefix := i.LastOutput.CommonPrefixes[i.NextPrefixIndex]
	i.NextPrefixIndex++

	return &PathItem{
		Path:        i.removePathPrefix(*nextPrefix.Prefix),
		IsDirectory: true,
		Age:         nil,
		Size:        0, // Directories don't have a size
	}
}

func (i *S3PathIterator) findNextMarker() *string {
	if i.LastOutput.NextMarker != nil {
		return i.LastOutput.NextMarker
	}

	// If there's no prefixes, then the last element is a file
	if len(i.LastOutput.CommonPrefixes) == 0 {
		lastElement := i.LastOutput.Contents[len(i.LastOutput.Contents)-1]
		return lastElement.Key
	}

	// If there's no files, then the last element is a prefix
	if len(i.LastOutput.Contents) == 0 {
		lastPrefix := i.LastOutput.CommonPrefixes[len(i.LastOutput.CommonPrefixes)-1]
		return lastPrefix.Prefix
	}

	// If there are prefixes and files, we need to alphabetically compare
	// the last element on each list and return the biggest.
	lastPrefix := i.LastOutput.CommonPrefixes[len(i.LastOutput.CommonPrefixes)-1]
	lastFile := i.LastOutput.Contents[len(i.LastOutput.Contents)-1]
	if strings.Compare(*lastPrefix.Prefix, *lastFile.Key) > 0 {
		return lastPrefix.Prefix
	}

	return lastFile.Key
}

func (i *S3PathIterator) Count() (int, error) {
	count := 0

	for !i.Done() {
		o, err := i.Next()
		if err == ErrNoMoreObjects {
			break
		}

		fmt.Printf("Counting %s\n", o.Path)

		if err != nil {
			return count, err
		}

		count++
	}

	return count, nil
}

func (i *S3PathIterator) Done() bool {
	return i.IsDone
}

func (i *S3PathIterator) removePathPrefix(path string) string {
	return strings.Replace(path, i.PathPrefix+"/", "", 1)
}
