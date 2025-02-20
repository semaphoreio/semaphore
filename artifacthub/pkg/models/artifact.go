package models

import (
	"bytes"
	"errors"
	"fmt"
	"time"

	"gorm.io/gorm"

	uuid "github.com/satori/go.uuid"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/db"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/util/log"
	"go.uber.org/zap"
	"google.golang.org/grpc/codes"
)

// Artifact represents the sql orm table structure how artifacts are stored.
type Artifact struct {
	ID               uuid.UUID `gorm:"primary_key;default:uuid_generate_v4()"`
	BucketName       string
	IdempotencyToken string
	Created          time.Time
	LastCleanedAt    time.Time
	DeletedAt        *time.Time
}

// CreateArtifact inserts a new artifact object to the database given by all its values.
func CreateArtifact(bucketName, idempotencyToken string) (*Artifact, error) {
	a := &Artifact{
		BucketName:       bucketName,
		IdempotencyToken: idempotencyToken,
		Created:          time.Now(),
	}

	if err := db.Conn().Create(a).Error; err != nil {
		return nil, log.ErrorCode(codes.Unknown, "Creating Artifact row in the database", err)
	}
	return a, nil
}

// Destroy removes an artifact from the database.
func (a *Artifact) Destroy() error {
	if err := db.Conn().Delete(&a).Error; err != nil {
		return log.ErrorCode(codes.NotFound, "Deleting Artifact row in the database", err)
	}
	return nil
}

func (a *Artifact) UpdateLastCleanedAt(timestamp time.Time) error {
	action := db.Conn().Model(&a).Update("LastCleanedAt", timestamp)
	if action.Error != nil {
		return action.Error
	}

	return nil
}

func (a *Artifact) UpdateDeleteAt(tx *gorm.DB, timestamp time.Time) error {
	return tx.Model(&a).Update("DeletedAt", timestamp).Error
}

// findArtifactByIdempotencyToken returns an artifact by its idempotency token, or an error.
func findArtifactByIdempotencyToken(idempotencyToken string) (*Artifact, error) {
	var a Artifact

	if err := db.Conn().Where("idempotency_token = ?", idempotencyToken).First(&a).Error; err != nil {
		return nil, err
	}

	return &a, nil
}

// FindArtifactByIdempotencyToken returns an artifact by its idempotency token, or an error.
// This wraps error message.
func FindArtifactByIdempotencyToken(idempotencyToken string) (a *Artifact, err error) {
	if a, err = findArtifactByIdempotencyToken(idempotencyToken); err != nil {
		err = log.ErrorCode(codes.NotFound, "Finding Artifact row by idempotency token in the db", err)
	} else {
		log.Info("found artifact by idempotency token %v",
			zap.String("idempotency token", idempotencyToken), zap.Reflect("artifact", a))
	}
	return
}

// findArtifactByID returns an artifact by its ID, or an error.
func findArtifactByID(tx *gorm.DB, artifactID string) (*Artifact, error) {
	var a Artifact

	if err := tx.Where("id = ?", artifactID).First(&a).Error; err != nil {
		return nil, err
	}

	return &a, nil
}

// FindArtifactByID returns an artifact by its ID, or an error.
// This wraps error message.
func FindArtifactByID(artifactID string) (a *Artifact, err error) {
	if a, err = findArtifactByID(db.Conn(), artifactID); err != nil {
		err = log.ErrorCode(codes.NotFound, "Finding Artifact row by ID in the db", err)
	}
	return
}

func FindArtifactByIDWithTx(tx *gorm.DB, artifactID string) (a *Artifact, err error) {
	if a, err = findArtifactByID(tx, artifactID); err != nil {
		err = log.ErrorCode(codes.NotFound, "Finding Artifact row by ID in the db", err)
	}
	return
}

func FindByBucketName(name string) (Artifact, error) {
	var artifact Artifact

	query := db.Conn().Where("bucket_name = ?", name).First(&artifact)

	return artifact, query.Error
}

// IterAllBuckets gets all bucket names by a callback function.
func IterAllBuckets(callback func(string)) error {
	rows, err := db.Conn().Table("artifacts").Select("bucket_name").Rows()
	if err != nil {
		return err
	}

	var bucketName string
	for rows.Next() {
		if err = rows.Scan(&bucketName); err != nil {
			return err
		}
		callback(bucketName)
	}
	return nil
}

func FetchForCleaning() ([]Artifact, error) {
	today := time.Now()
	startOfToday := time.Date(today.Year(), today.Month(), today.Day(), 0, 0, 0, 0, time.Local)

	artifacts := []Artifact{}

	fmt.Println("Fetching all buckets last cleaned before:", startOfToday)

	query := db.Conn().Where("last_cleaned_at < ? OR last_cleaned_at IS NULL", startOfToday).Find(&artifacts)
	if query.Error != nil {
		return nil, query.Error
	}

	return artifacts, nil
}

// ListBucketsForIDs returns an ID => bucket name map for the given IDs.
func ListBucketsForIDs(IDs []string) (result map[string]string, err error) {
	result = map[string]string{}
	rows, err := db.Conn().Table("artifacts").Select("id, bucket_name").Where("id in (?)", IDs).Rows()
	if err != nil {
		return nil, log.ErrorCode(codes.NotFound, "Listing Bucket names for IDs", err)
	}

	var ID, bucketName string
	var errB bytes.Buffer
	for rows.Next() {
		if err = rows.Err(); err != nil {
			// the rest should be sent anyway
			errB.WriteString(err.Error())
			errB.WriteString("; ")
		}

		if err = rows.Scan(&ID, &bucketName); err != nil {
			errB.WriteString(err.Error())
			errB.WriteString("; ")
		}

		result[ID] = bucketName
	}

	if errB.Len() > 0 {
		err = log.ErrorCode(codes.Unknown, "ListBuckets errors: ", errors.New(errB.String()))
	}

	return result, err
}

// BucketCount returns the current number of buckets.
func BucketCount() (res int64, err error) {
	if err = db.Conn().Table("artifacts").Distinct("bucket_name").Count(&res).Error; err != nil {
		return 0, log.ErrorCode(codes.Unknown, "Count error: ", err)
	}
	return res, nil
}

// FindNextBucket returns a bucket name that is after the given bucket name. Ordering
// goes with created time AND bucket name so nothing is missed.
// This wraps error message is any.
func FindNextBucket(lastBucketName string) (string, error) {
	mainQuery := db.Conn().Debug().Table("artifacts").Select("bucket_name")
	if len(lastBucketName) > 0 {
		subQuery := db.Conn().Table("artifacts").
			Select("created").
			Where("bucket_name = ?", lastBucketName)

		mainQuery = mainQuery.Where("created >= (?)", subQuery).Offset(1)
	}

	res := Artifact{}
	if err := mainQuery.Order("created, bucket_name").First(&res).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return "", nil
		}
		return "", log.ErrorCode(codes.Unknown, "Find next bucket: ", err)
	}
	return res.BucketName, nil
}
