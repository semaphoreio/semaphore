package config

import (
	"flag"
	"os"
)

func ZebraEndpoint() string {
	if flag.Lookup("test.v") == nil {
		return os.Getenv("ZEBRA_INTERNAL_GRPC_API_ENDPOINT")
	}

	return "0.0.0.0:50052"
}

func Loghub2Endpoint() string {
	if flag.Lookup("test.v") == nil {
		return os.Getenv("LOGHUB2_INTERNAL_GRPC_API_ENDPOINT")
	}

	return "0.0.0.0:50052"
}

func FeatureAPIEndpoint() string {
	if flag.Lookup("test.v") == nil {
		return os.Getenv("FEATURE_INTERNAL_GRPC_API_ENDPOINT")
	}

	return "0.0.0.0:50052"
}
