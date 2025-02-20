package hub

import (
	"fmt"

	gorm "github.com/jinzhu/gorm"
	_ "github.com/jinzhu/gorm/dialects/postgres" // blank import
	config "github.com/semaphoreio/semaphore/repohub/pkg/config"
)

const psqlInfoTemplate = "host=%s port=%s user=%s password=%s dbname=%s sslmode=%s application_name=%s"

func DbConnection() *gorm.DB {
	c := config.DbConfiguration()

	psqlInfo := fmt.Sprintf(psqlInfoTemplate, c.DbHost, c.DbPort, c.DbUser, c.DbPass, c.DbName, c.Ssl, c.ApplicationName)

	db, err := gorm.Open("postgres", psqlInfo)
	db.LogMode(false)

	if err != nil {
		panic(err)
	}

	return db
}
