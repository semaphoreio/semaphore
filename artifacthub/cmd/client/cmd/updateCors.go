package cmd

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/semaphoreio/semaphore/artifacthub/pkg/api/descriptors/artifacthub"
	"github.com/spf13/cobra"
)

var (
	// updateCorsCmd represents the updateCors command
	updateCorsCmd = &cobra.Command{
		Use:   "updateCors",
		Short: "update CORS for multiple buckets",
		Long: `This command updates current CORS settings for multiple buckets.
The buckets are ordered by created time, then by bucket name.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			bucketName := startBucketName
			if count == 0 {
				var err error
				count, err = getCount()
				if err != nil {
					return err
				}
				if len(startBucketName) > 0 {
					if diff == 0 || diff < -1 {
						return errors.New(`index-diff must be set when start-bucket-name is set
but count is not. If you know the index of start-bucket-name, set that number.
Otherwise set it to -1, but then log indexing won't be accurate`)
					}
					if diff > 0 {
						count -= diff
					}
				}
			}
			for i := 0; i < count; i++ {
				bucketName, _ = updateOne(i+1, bucketName)
				if len(bucketName) == 0 {
					break
				}
				if wait > 0 {
					time.Sleep(time.Millisecond * time.Duration(wait))
				}
			}
			printEnding(bucketName)
			return nil
		},
	}
	startBucketName   string
	count, diff, wait int
)

func updateOne(index int, bucketName string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	if len(bucketName) == 0 {
		fmt.Printf("[1/%d] Updating cors for the first bucket... ", count)
	} else {
		fmt.Printf("[%d/%d] Updating cors for bucket '%s'... ", index, count, bucketName)
	}
	req := &artifacthub.UpdateCORSRequest{}
	req.BucketName = bucketName
	resp, err := client.UpdateCORS(ctx, req)
	if err != nil {
		fmt.Printf("ERROR: %v\n", err)
		if resp != nil {
			return resp.NextBucketName, err
		}
		return "", err
	}
	fmt.Println("OK")
	return resp.NextBucketName, nil
}

func printEnding(nextBucketName string) {
	if len(nextBucketName) == 0 {
		fmt.Println("This was the last bucket in order(created, bucketName).")
		return
	}
	fmt.Printf("Next bucket in order(created, bucketName) will be '%s'.\n", nextBucketName)
}

func init() {
	rootCmd.AddCommand(updateCorsCmd)
	updateCorsCmd.Flags().StringVarP(&startBucketName, "start-bucket-name", "s", "",
		"the first bucket to update, if empty: starts from the top")
	updateCorsCmd.Flags().IntVarP(&count, "count", "c", 0,
		"the number of buckets to update, if empty or zero: till the end")
	updateCorsCmd.Flags().IntVarP(&diff, "index-diff", "d", 0,
		"the index of the first bucket if start-bucket-name is set but count is not")
	updateCorsCmd.Flags().IntVarP(&wait, "wait-ms", "w", 0,
		"wait this amount of time in milliseconds between two update calls")
}
