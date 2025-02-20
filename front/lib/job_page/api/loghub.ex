defmodule JobPage.Api.Loghub do
  defstruct [:final, :events, :first_event, :last_event]

  alias JobPage.GrpcConfig

  def fetch(job_id, starting_line, tracing_headers \\ nil) do
    Watchman.benchmark({"fetch_logs.duration", ["#{job_id}"]}, fn ->
      req =
        InternalApi.Loghub.GetLogEventsRequest.new(job_id: job_id, starting_line: starting_line)

      {:ok, channel} = GRPC.Stub.connect(GrpcConfig.endpoint(:loghub_api_grpc_endpoint))

      config = Application.get_env(:front, JobPage.Api.Loghub, [])
      timeout = Keyword.get(config, :timeout, 30_000)

      case InternalApi.Loghub.Loghub.Stub.get_log_events(channel, req,
             metadata: tracing_headers,
             timeout: timeout
           ) do
        {:ok, response} ->
          if response.status.code == 0 do
            Watchman.increment("fetch_logs.success")
            last_event = Enum.count(response.events) + starting_line

            {:ok,
             %__MODULE__{
               final: response.final,
               events: response.events,
               first_event: starting_line,
               last_event: last_event
             }}
          else
            Watchman.increment("fetch_logs.failure")

            {:error, response.status.message}
          end

        {:error, _error} ->
          Watchman.increment("fetch_logs.failure")

          {:error, "Error while fetching events!"}
      end
    end)
  end
end
