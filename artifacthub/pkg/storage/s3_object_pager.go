package storage

import (
	"strings"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/s3"
)

type S3ObjectPager struct {
	Client     *s3.S3
	BucketName string
	NextMarker string
	MaxKeys    int64
	Prefix     string
	PathPrefix string
}

var _ ObjectPager = &S3ObjectPager{}

func (p *S3ObjectPager) NextPage() ([]*Object, string, error) {
	output, err := p.fetch()
	if err != nil {
		return nil, "", err
	}

	objects := []*Object{}

	for _, object := range output.Contents {
		age := time.Since(*object.LastModified)
		objects = append(objects, &Object{
			Path: p.removePathPrefix(*object.Key),
			Age:  &age,
		})
	}

	if *output.IsTruncated {
		p.NextMarker = p.findNextMarker(output)
	} else {
		p.NextMarker = ""
	}

	return objects, p.NextMarker, nil
}

func (p *S3ObjectPager) fetch() (*s3.ListObjectsOutput, error) {
	input := s3.ListObjectsInput{
		Bucket:  aws.String(p.BucketName),
		Prefix:  aws.String(p.Prefix),
		MaxKeys: aws.Int64(p.MaxKeys),
	}

	if p.NextMarker != "" {
		input.Marker = aws.String(p.NextMarker)
	}

	output, err := p.Client.ListObjects(&input)
	if err != nil {
		return nil, err
	}

	return output, nil
}

func (p *S3ObjectPager) findNextMarker(output *s3.ListObjectsOutput) string {
	if output.NextMarker != nil {
		return *output.NextMarker
	}

	if len(output.Contents) == 0 {
		return ""
	}

	lastElement := output.Contents[len(output.Contents)-1]
	return *lastElement.Key
}

func (p *S3ObjectPager) removePathPrefix(path string) string {
	return strings.Replace(path, p.PathPrefix+"/", "", 1)
}
