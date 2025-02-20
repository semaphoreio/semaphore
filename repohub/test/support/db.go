package testsupport

import (
	"fmt"

	gorm "github.com/jinzhu/gorm"
	hub "github.com/semaphoreio/semaphore/repohub/pkg/hub"
	models "github.com/semaphoreio/semaphore/repohub/pkg/models"
)

var (
	DB *gorm.DB
)

func ConnectDB() {
	DB = hub.DbConnection()
}

func PurgeDB() {
	err := DB.Delete(&models.Repository{}).Error

	if err != nil {
		fmt.Printf("%s\n", err)
		panic("Failed to purge database")
	}
}
