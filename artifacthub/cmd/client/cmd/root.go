package cmd

import (
	"fmt"
	"os"
	"time"

	"github.com/spf13/cobra"
)

var timeout = time.Second * 15

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "client",
	Short: "gRPC accessible artifacthub functions",
	Long:  `A client to call exported artifacthub functionality through gRPC.`,
	PersistentPreRun: func(cmd *cobra.Command, args []string) {
		dial()
	},
	PersistentPostRun: func(cmd *cobra.Command, args []string) {
		quit()
	},
}

// Execute adds all child commands to the root command and sets flags appropriately.
// This is called by main.main(). It only needs to happen once to the rootCmd.
func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}

func init() {
	rootCmd.PersistentFlags().StringVarP(&serverAddr, "server-address", "a", "",
		"the private server address in the format of host:port")
}
