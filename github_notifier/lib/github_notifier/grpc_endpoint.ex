defmodule GithubNotifier.GrpcEndpoint do
  use GRPC.Endpoint

  run(GithubNotifier.Services.Api)
end
