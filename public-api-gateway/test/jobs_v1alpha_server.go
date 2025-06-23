package main

import (
	"log"

	"golang.org/x/net/context"
	"google.golang.org/grpc/metadata"

	pb "github.com/semaphoreio/semaphore/public-api-gateway/api/jobs.v1alpha"
)

// jobsServer implements the JobsApiServer interface
var _ pb.JobsApiServer = &jobsServer{}

type jobsServer struct{}

// GetJob returns a job by ID
func (s *jobsServer) GetJob(ctx context.Context, req *pb.GetJobRequest) (*pb.Job, error) {
	log.Printf("Incoming GetJob Request")
	logRequestMetadata(ctx)

	jobID := req.GetJobId()
	log.Printf("Job ID: %s", jobID)

	return &pb.Job{
		Metadata: &pb.Job_Metadata{
			Id: jobID,
		},
		Status: &pb.Job_Status{
			State: pb.Job_Status_RUNNING,
		},
	}, nil
}

// ListJobs returns a list of jobs
func (s *jobsServer) ListJobs(ctx context.Context, req *pb.ListJobsRequest) (*pb.ListJobsResponse, error) {
	log.Printf("Incoming ListJobs Request")
	logRequestMetadata(ctx)

	return &pb.ListJobsResponse{
		Jobs: []*pb.Job{
			{
				Metadata: &pb.Job_Metadata{
					Id: "job-1",
				},
				Status: &pb.Job_Status{
					State: pb.Job_Status_RUNNING,
				},
			},
			{
				Metadata: &pb.Job_Metadata{
					Id: "job-2",
				},
				Status: &pb.Job_Status{
					State:  pb.Job_Status_FINISHED,
					Result: pb.Job_Status_PASSED,
				},
			},
		},
	}, nil
}

// StopJob stops a job by ID
func (s *jobsServer) StopJob(ctx context.Context, req *pb.StopJobRequest) (*pb.Empty, error) {
	log.Printf("Incoming StopJob Request")
	logRequestMetadata(ctx)

	jobID := req.GetJobId()
	log.Printf("Stopping Job ID: %s", jobID)

	return &pb.Empty{}, nil
}

// GetJobDebugSSHKey returns debug SSH key for a job
func (s *jobsServer) GetJobDebugSSHKey(ctx context.Context, req *pb.GetJobDebugSSHKeyRequest) (*pb.JobDebugSSHKey, error) {
	log.Printf("Incoming GetJobDebugSSHKey Request")
	logRequestMetadata(ctx)

	jobID := req.GetJobId()
	log.Printf("Getting Debug SSH Key for Job ID: %s", jobID)

	return &pb.JobDebugSSHKey{
		Key: "mock-ssh-key",
	}, nil
}

// CreateJob creates a new job
func (s *jobsServer) CreateJob(ctx context.Context, req *pb.Job) (*pb.Job, error) {
	log.Printf("Incoming CreateJob Request")
	logRequestMetadata(ctx)

	return &pb.Job{
		Metadata: &pb.Job_Metadata{
			Id: "new-job-id",
		},
		Status: &pb.Job_Status{
			State: pb.Job_Status_PENDING,
		},
	}, nil
}

// CreateDebugJob creates a debug job
func (s *jobsServer) CreateDebugJob(ctx context.Context, req *pb.CreateDebugJobRequest) (*pb.Job, error) {
	log.Printf("Incoming CreateDebugJob Request")
	logRequestMetadata(ctx)

	return &pb.Job{
		Metadata: &pb.Job_Metadata{
			Id: "debug-job-id",
		},
		Status: &pb.Job_Status{
			State: pb.Job_Status_PENDING,
		},
	}, nil
}

// CreateDebugProject creates a debug project
func (s *jobsServer) CreateDebugProject(ctx context.Context, req *pb.CreateDebugProjectRequest) (*pb.Job, error) {
	log.Printf("Incoming CreateDebugProject Request")
	logRequestMetadata(ctx)

	return &pb.Job{
		Metadata: &pb.Job_Metadata{
			Id: "debug-project-job-id",
		},
		Status: &pb.Job_Status{
			State: pb.Job_Status_PENDING,
		},
	}, nil
}

// Helper function to log request metadata
func logRequestMetadata(ctx context.Context) {
	log.Printf("---------------")
	headers, _ := metadata.FromIncomingContext(ctx)

	log.Printf("Headers:")
	for key, values := range headers {
		for _, value := range values {
			log.Printf("  %s: %s", key, value)
		}
	}
	log.Printf("---------------")
}
