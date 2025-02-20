// Package database holds the database connection functions and other utilities.
package database

import (
	"flag"
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/semaphoreio/semaphore/velocity/pkg/config"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	gormLogger "gorm.io/gorm/logger"
)

var dbInstance *gorm.DB

func Conn() *gorm.DB {
	if dbInstance == nil {
		dbInstance = connect()
	}

	return dbInstance.Session(&gorm.Session{})
}

func connect() *gorm.DB {
	c := config.DatabaseConfiguration()

	dsnTemplate := "host=%s port=%s user=%s password=%s dbname=%s sslmode=%s application_name=%s"
	dsn := fmt.Sprintf(dsnTemplate, c.Host, c.Port, c.User, c.Password, c.Name, c.Ssl, c.ApplicationName)

	logger := gormLogger.New(log.New(os.Stdout, "\r\n", log.LstdFlags), gormLogger.Config{
		SlowThreshold:             200 * time.Millisecond,
		LogLevel:                  gormLogger.Warn,
		Colorful:                  true,
		IgnoreRecordNotFoundError: true,
	})

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{Logger: logger})
	if err != nil {
		panic(err)
	}

	sqlDB, err := db.DB()
	if err != nil {
		panic(err)
	}

	sqlDB.SetMaxOpenConns(dbPoolSize())

	return db
}

func dbPoolSize() int {
	poolSize := os.Getenv("DB_POOL_SIZE")

	size, err := strconv.Atoi(poolSize)
	if err != nil {
		return 1
	}

	return size
}

func Truncate(tables ...string) error {
	panicIfNotTestEnvironment()
	panicIfMissingParam(tables)

	query := "TRUNCATE TABLE"
	for _, table := range tables {
		query = fmt.Sprintf("%s %s,", query, table)
	}
	query = strings.TrimSuffix(query, ",")

	return Conn().Exec(query).Error
}

func panicIfMissingParam(tables []string) {
	if len(tables) == 0 {
		panic("missing table param")
	}
}

func panicIfNotTestEnvironment() {
	if flag.Lookup("test.v") == nil {
		panic("trying to truncate database in non-test environment")
	}
}
