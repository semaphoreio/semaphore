package cmd

import (
	"context"
	"fmt"

	"github.com/semaphoreio/semaphore/artifacthub/pkg/api/descriptors/artifacthub"
	"github.com/spf13/cobra"
)

// currentNumberOfBucketsCmd represents the currentNumberOfBuckets command
var currentNumberOfBucketsCmd = &cobra.Command{
	Use:   "currentNumberOfBuckets",
	Short: "number of buckets",
	Long:  `Gets number of buckets from artifacthub server through gRPC and prints it.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		count, err := getCount()
		if err != nil {
			return err
		}
		fmt.Printf("Number of buckets: %d\n", count)
		return nil
	},
}

func getCount() (int, error) {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	resp, err := client.CountBuckets(ctx, &artifacthub.CountBucketsRequest{})
	if err != nil {
		return 0, err
	}
	return int(resp.BucketCount), nil
}

func init() {
	rootCmd.AddCommand(currentNumberOfBucketsCmd)
}
