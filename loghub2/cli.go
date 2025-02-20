package main

import (
	"context"
	"log"
	"os"
	"strconv"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
	pb "github.com/semaphoreio/semaphore/loghub2/pkg/protos/loghub2"
	protos "github.com/semaphoreio/semaphore/loghub2/pkg/protos/server_farm.mq.job_state_exchange"
	"github.com/semaphoreio/semaphore/loghub2/pkg/utils"
	"google.golang.org/grpc"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// Dev utility to help with some actions needed when testing in your dev environment
// Actions
// - `done JOB_ID` to publish a job_teardown_finished message for JOB_ID
// - `token JOB_ID TOKEN_TYPE` to generate a TOKEN_TYPE jwt token for JOB_ID
func main() {
	action := os.Args[1]

	switch action {
	case "done":
		jobId := os.Args[2]
		selfHosted, _ := strconv.ParseBool(os.Args[3])
		_ = publishMessage("amqp://guest:guest@localhost:5672", "server_farm.job_state_exchange", "job_teardown_finished", jobId, selfHosted)
	case "token":
		jobId := os.Args[2]
		tokenType := os.Args[3]
		generateToken(jobId, tokenType)
	}
}

func generateToken(jobId, tokenType string) {
	log.Printf("Generating token for %s", jobId)
	conn, err := grpc.Dial("localhost:50051", grpc.WithInsecure())
	if err != nil {
		log.Fatalf("Error dialing: %v", err)
	}

	defer conn.Close()
	client := pb.NewLoghub2Client(conn)

	var request pb.GenerateTokenRequest
	if tokenType == "PUSH" {
		request = pb.GenerateTokenRequest{JobId: jobId, Type: pb.TokenType_PUSH}
	} else {
		request = pb.GenerateTokenRequest{JobId: jobId, Type: pb.TokenType_PULL}
	}

	response, err := client.GenerateToken(context.Background(), &request)
	if err != nil {
		log.Fatalf("Error generating token: %v", err)
	}

	log.Printf("Generated token: %v", response)
}

func publishMessage(amqpURL string, exchange string, routingKey string, jobId string, selfHosted bool) error {
	config := amqp.Config{Properties: amqp.NewConnectionProperties()}
	config.Properties.SetClientConnectionName(utils.ClientConnectionName())

	connection, err := amqp.DialConfig(amqpURL, config)
	if err != nil {
		return err
	}

	defer connection.Close()

	channel, err := connection.Channel()
	if err != nil {
		return err
	}

	defer channel.Close()

	jobFinished := &protos.JobFinished{JobId: jobId, SelfHosted: selfHosted, Timestamp: timestamppb.New(time.Now())}
	data, err := proto.Marshal(jobFinished)
	if err != nil {
		return err
	}

	log.Printf("Publishing message in %s with routing key %s", exchange, routingKey)
	err = channel.Publish(exchange, routingKey, false, false, amqp.Publishing{Body: data})
	if err != nil {
		return err
	}

	return nil
}
