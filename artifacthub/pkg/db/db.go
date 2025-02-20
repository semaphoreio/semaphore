package db

import (
	"errors"
	"fmt"
	"log"
	"os"
	"time"

	postgres "gorm.io/driver/postgres"
	gorm "gorm.io/gorm"
	gormLogger "gorm.io/gorm/logger"
)

const psqlInfoTemplate = "host=%s port=%s user=%s password=%s dbname=%s sslmode=%s application_name=%s"

// DbConfig contains information to connect to the database.
type DbConfig struct {
	DbHost          string
	DbPort          string
	DbName          string
	DbUser          string
	DbPass          string
	Ssl             string
	ApplicationName string
	LogLevel        gormLogger.LogLevel
}

var dbInstance *gorm.DB

func Conn() *gorm.DB {
	if dbInstance == nil {
		dbInstance = connectDb()
	}

	return dbInstance.Session(&gorm.Session{})
}

// ConnectDb connects to the database with information from environment variables.
func connectDb() *gorm.DB {
	c, err := dbConfigFromEnv()
	if err != nil {
		panic(err)
	}

	logger := gormLogger.New(log.New(os.Stdout, "\r\n", log.LstdFlags), gormLogger.Config{
		SlowThreshold:             200 * time.Millisecond,
		LogLevel:                  c.LogLevel,
		Colorful:                  true,
		IgnoreRecordNotFoundError: true,
	})

	psqlInfo := fmt.Sprintf(psqlInfoTemplate, c.DbHost, c.DbPort, c.DbUser, c.DbPass, c.DbName, c.Ssl, c.ApplicationName)
	db, err := gorm.Open(postgres.Open(psqlInfo), &gorm.Config{Logger: logger})
	if err != nil {
		panic(err)
	}

	return db
}

// dbConfigFromEnv returns database connection information from environment variables.
func dbConfigFromEnv() (*DbConfig, error) {
	if os.Getenv("DB_HOST") == "" {
		return nil, errors.New("DB_HOST is not set")
	}

	postgresDbSSL := os.Getenv("POSTGRES_DB_SSL")
	sslMode := "disable"
	if postgresDbSSL == "true" {
		sslMode = "require"
	}

	logLevel := gormLogger.Warn
	if os.Getenv("DB_DEBUG_LOGS") == "true" {
		logLevel = gormLogger.Info
	}

	return &DbConfig{
		DbHost:          os.Getenv("DB_HOST"),
		DbPort:          os.Getenv("DB_PORT"),
		DbName:          os.Getenv("DB_NAME"),
		DbPass:          os.Getenv("DB_PASSWORD"),
		DbUser:          os.Getenv("DB_USERNAME"),
		Ssl:             sslMode,
		ApplicationName: os.Getenv("APPLICATION_NAME"),
		LogLevel:        logLevel,
	}, nil
}
