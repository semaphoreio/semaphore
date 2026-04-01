package main

import (
	"context"
	"fmt"
	"os"

	gcsstorage "cloud.google.com/go/storage"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/db"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/models"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/storage"
)

func main() {
	if os.Getenv("DB_HOST") == "" {
		fmt.Println("DB_HOST is not set. Required env vars: DB_HOST, DB_PORT, DB_NAME, DB_USERNAME, DB_PASSWORD")
		os.Exit(1)
	}

	sqlDB, err := db.Conn().DB()
	if err != nil {
		fmt.Printf("Failed to get database connection: %v\n", err)
		os.Exit(1)
	}
	if err = sqlDB.Ping(); err != nil {
		fmt.Printf("Failed to connect to database: %v\n", err)
		os.Exit(1)
	}

	gcsClient, err := storage.NewGcsClient(os.Getenv("GOOGLE_APPLICATION_CREDENTIALS"))
	if err != nil {
		fmt.Printf("Failed to create GCS client: %v\n", err)
		os.Exit(1)
	}

	lifecycle := storage.ArtifactLifecycle()
	if len(lifecycle.Rules) == 0 {
		fmt.Println("No lifecycle rules configured. Set ARTIFACT_*_RETENTION_DAYS env vars.")
		os.Exit(1)
	}

	fmt.Printf("Lifecycle rules to apply (%d rules):\n", len(lifecycle.Rules))
	for _, r := range lifecycle.Rules {
		fmt.Printf("  - Delete objects with prefix %v after %d days\n", r.Condition.MatchesPrefix, r.Condition.AgeInDays)
	}
	fmt.Println()

	var total, updated, failed int

	err = models.IterAllBuckets(func(bucketName string) {
		total++
		ctx := context.Background()

		_, err := gcsClient.Client.Bucket(bucketName).Update(ctx, gcsstorage.BucketAttrsToUpdate{
			Lifecycle: &lifecycle,
		})

		if err != nil {
			failed++
			fmt.Printf("FAIL %s: %v\n", bucketName, err)
			return
		}

		updated++
		if updated%100 == 0 {
			fmt.Printf("... updated %d buckets so far\n", updated)
		}
	})

	if err != nil {
		fmt.Printf("Database iteration error: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("\nDone. Total: %d, Updated: %d, Failed: %d\n", total, updated, failed)

	if failed > 0 {
		os.Exit(1)
	}
}
