package storage

import "os"

func New() (Client, error) {
	switch os.Getenv("ARTIFACT_STORAGE_BACKEND") {
	case "s3":
		s3Options := S3Options{
			BucketName:      os.Getenv("ARTIFACT_STORAGE_S3_BUCKET"),
			URL:             os.Getenv("ARTIFACT_STORAGE_S3_URL"),
			AccessKeyID:     os.Getenv("AWS_ACCESS_KEY_ID"),
			SecretAccessKey: os.Getenv("AWS_SECRET_ACCESS_KEY"),
			Region:          os.Getenv("AWS_REGION"),
		}
		return NewS3Client(s3Options)
	default:
		return NewGcsClient(os.Getenv("GOOGLE_APPLICATION_CREDENTIALS"))
	}
}
