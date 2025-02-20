// Package shutdown contains a helper function to handle shutdowns.
package shutdown

import (
	"context"
	"log"
	"os"
	"os/signal"
)

func Set(ctx context.Context) {
	// not a safe exit, rethink and add graceful shutdown
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt)
	go func() {
		for range c {
			// sig is a ^C, handle it

			ctx.Done() //notifies go routines that they should stop

			log.Println("quitting...")
			os.Exit(0)
		}
	}()
}
