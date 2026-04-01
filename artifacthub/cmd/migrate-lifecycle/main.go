package main

import (
	"context"
	"fmt"
	"os"
	"sync/atomic"

	gcsstorage "cloud.google.com/go/storage"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/models"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/storage"
)

func main() {
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

	var total, updated, failed int64

	err = models.IterAllBuckets(func(bucketName string) {
		atomic.AddInt64(&total, 1)
		ctx := context.Background()

		_, err := gcsClient.Client.Bucket(bucketName).Update(ctx, gcsstorage.BucketAttrsToUpdate{
			Lifecycle: &lifecycle,
		})

		if err != nil {
			atomic.AddInt64(&failed, 1)
			fmt.Printf("FAIL %s: %v\n", bucketName, err)
			return
		}

		atomic.AddInt64(&updated, 1)
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
