package database

import (
	"context"
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	gorm "gorm.io/gorm"
)

func Test__WithBlockingAdvisoryLock(t *testing.T) {
	executions := 100

	var wg sync.WaitGroup

	// Used to assert that only one execution happens at a time
	var executing []int

	// Used to assert that we executed
	// the function the proper amount of times
	var executed int

	for i := 0; i < executions; i++ {
		wg.Add(1)
		count := i

		go func() {
			defer wg.Done()
			_ = WithBlockingAdvisoryLock(context.Background(), "organizationID", func(tx *gorm.DB) error {
				executing = append(executing, count)
				assert.Len(t, executing, 1)
				time.Sleep(50 * time.Millisecond)
				executing = executing[len(executing):]
				executed++
				return nil
			})
		}()
	}

	wg.Wait()
	assert.Equal(t, executed, executions)
}

func Test__WithBlockingAdvisoryLockWithTimeout(t *testing.T) {
	// No timeout on the first one
	go func() {
		err := WithBlockingAdvisoryLock(context.Background(), "organizationID", func(tx *gorm.DB) error {
			time.Sleep(5 * time.Second)
			return nil
		})

		assert.NoError(t, err)
	}()

	// We wait a little bit to make sure the first go routine always start first.
	time.Sleep(time.Second)
	ctx, cancel := context.WithTimeout(context.Background(), 1*time.Second)
	defer cancel()

	// The second one fails due to a timeout
	err := WithBlockingAdvisoryLock(ctx, "organizationID", func(tx *gorm.DB) error {
		return nil
	})

	if assert.Error(t, err) {
		assert.Equal(t, err.Error(), "context deadline exceeded")
	}
}
