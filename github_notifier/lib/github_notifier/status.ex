defmodule GithubNotifier.Status do
  require Logger

  def create(nil, _request_id), do: nil

  def create(data, request_id) when is_list(data) do
    Enum.each(data, fn x -> create(x, request_id) end)
  end

  def create(data, request_id) do
    key =
      "#{data.repository_id}/#{data.sha}/#{data.ppl_id}/#{data.context}/#{data.state}/#{data.description}"

    Cachex.transaction!(:store, [key], fn cache ->
      case Cachex.get(cache, key) do
        {:ok, true} ->
          Logger.info("[#{request_id}] Skipping Status: #{key}")

        _ ->
          Logger.info("[#{request_id}] Creating Status: #{key}")
          Task.async(fn -> create_status(data) end)
          Logger.info("[#{request_id}] Creating Status Finished: #{key}")
          Cachex.put!(cache, key, true)
          Cachex.expire(cache, key, :timer.hours(5))
          Logger.info("[#{request_id}] Creating Status Cache Updated: #{key}")
      end
    end)
  end

  defp create_status(data) do
    Watchman.benchmark("create_status.duration", fn ->
      req =
        InternalApi.Repository.CreateBuildStatusRequest.new(
          repository_id: data.repository_id,
          commit_sha: data.sha,
          status: map_status(data.state),
          url: data.url,
          description: data.description,
          context: data.context
        )

      {:ok, channel} =
        GRPC.Stub.connect(
          Application.fetch_env!(:github_notifier, :repositoryhub_api_grpc_endpoint)
        )

      Logger.debug(fn ->
        "Creating Status repository_id: #{req.repository_id}"
      end)

      Logger.debug(inspect(req))

      res =
        InternalApi.Repository.RepositoryService.Stub.create_build_status(channel, req,
          timeout: 30_000
        )

      case res do
        {:ok, %{code: :OK}} ->
          Watchman.increment(
            internal: "set_commit_status.success",
            external: {"set_commit_status", [result: "success"]}
          )

        _ ->
          Watchman.increment(
            internal: "set_commit_status.failure",
            external: {"set_commit_status", [result: "failure"]}
          )
      end

      Logger.debug("Received Create Status response")
      Logger.debug(inspect(res))

      :ok
    end)
  end

  alias InternalApi.Repository.CreateBuildStatusRequest.Status
  defp map_status("success"), do: Status.value(:SUCCESS)
  defp map_status("pending"), do: Status.value(:PENDING)
  defp map_status("failure"), do: Status.value(:FAILURE)
end
