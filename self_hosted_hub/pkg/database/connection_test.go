package database

import (
	"database/sql"
	"sync"
	"sync/atomic"
	"testing"

	"github.com/stretchr/testify/assert"
	postgres "gorm.io/driver/postgres"
	gorm "gorm.io/gorm"
)

// lazyDB builds a gorm handle without touching the network.
func lazyDB(t *testing.T) *gorm.DB {
	t.Helper()
	sqlDB, err := sql.Open("pgx", "host=127.0.0.1 port=1 user=x dbname=x sslmode=disable")
	assert.NoError(t, err)
	db, err := gorm.Open(postgres.New(postgres.Config{Conn: sqlDB}), &gorm.Config{DisableAutomaticPing: true})
	assert.NoError(t, err)
	return db
}

func withConnectFn(t *testing.T, fn func() *gorm.DB) {
	t.Helper()
	origFn, origInst := connectFn, dbInstance
	dbInstance = nil
	connectFn = fn
	t.Cleanup(func() { connectFn, dbInstance = origFn, origInst })
}

func Test__Conn__RetriesAfterFailedConnect(t *testing.T) {
	real := lazyDB(t)
	var calls int32
	withConnectFn(t, func() *gorm.DB {
		if atomic.AddInt32(&calls, 1) == 1 {
			panic("db unreachable")
		}
		return real
	})

	assert.Panics(t, func() { Conn() })
	assert.NotPanics(t, func() { assert.NotNil(t, Conn()) })
	assert.NotPanics(t, func() { Conn() })
	assert.Equal(t, int32(2), atomic.LoadInt32(&calls))
}

func Test__Conn__ConnectsOnceWhenSuccessful(t *testing.T) {
	real := lazyDB(t)
	var calls int32
	withConnectFn(t, func() *gorm.DB {
		atomic.AddInt32(&calls, 1)
		return real
	})

	Conn()
	Conn()
	assert.Equal(t, int32(1), atomic.LoadInt32(&calls))
}

func Test__Conn__ConcurrentCallersShareOneConnect(t *testing.T) {
	real := lazyDB(t)
	var calls int32
	withConnectFn(t, func() *gorm.DB {
		atomic.AddInt32(&calls, 1)
		return real
	})

	var wg sync.WaitGroup
	for i := 0; i < 50; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			assert.NotNil(t, Conn())
		}()
	}
	wg.Wait()
	assert.Equal(t, int32(1), atomic.LoadInt32(&calls))
}
