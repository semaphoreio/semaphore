defmodule JobPage.Api.Job do
  alias JobPage.GrpcConfig

  def fetch(job_id, tracing_headers \\ nil) do
    Watchman.benchmark("fetch_job.duration", fn ->
      req = InternalApi.ServerFarm.Job.DescribeRequest.new(job_id: job_id)

      {:ok, channel} = GRPC.Stub.connect(GrpcConfig.endpoint(:job_api_grpc_endpoint))

      {:ok, response} =
        InternalApi.ServerFarm.Job.JobService.Stub.describe(channel, req,
          metadata: tracing_headers,
          timeout: 30_000
        )

      if response.status.code == InternalApi.ResponseStatus.Code.value(:OK) do
        response.job
      else
        nil
      end
    end)
  end
end
