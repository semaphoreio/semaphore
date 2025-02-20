package main

import (
	"log"
	"os"
	"strconv"

	"github.com/semaphoreio/semaphore/encryptor/pkg/api"
	"github.com/semaphoreio/semaphore/encryptor/pkg/crypto"
)

func startAPI() {
	log.Println("Starting API")

	port, err := strconv.Atoi(os.Getenv("GRPC_API_PORT"))
	if err != nil {
		log.Panicf("Public API port can't be empty")
	}

	encryptor, err := crypto.NewEncryptor(os.Getenv("ENCRYPTOR_TYPE"))
	if err != nil {
		log.Panicf("Failed to create encryptor: %v", err)
	}

	log.Println("Starting API")
	api.RunServer(port, encryptor)
}

func main() {
	if os.Getenv("START_API") == "yes" {
		go startAPI()
	}

	log.Println("Envelope encryptor service is UP.")

	select {}
}
