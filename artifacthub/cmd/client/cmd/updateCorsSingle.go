package cmd

import (
	"github.com/spf13/cobra"
)

var (
	// updateCorsSingleCmd represents the updateCorsSingle command
	updateCorsSingleCmd = &cobra.Command{
		Use:   "updateCorsSingle",
		Short: "update CORS for a single bucket",
		Long:  `This command updates current CORS settings for a single bucket.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			count = 1
			nextBucketName, err := updateOne(1, bucketName)
			if err != nil {
				return err
			}
			printEnding(nextBucketName)
			return nil
		},
	}
	bucketName string
)

func init() {
	updateCorsSingleCmd.Flags().StringVarP(&bucketName, "bucket-name", "b", "", "the bucket to update")
	_ = updateCorsSingleCmd.MarkFlagRequired("bucket-name")
	rootCmd.AddCommand(updateCorsSingleCmd)
}
