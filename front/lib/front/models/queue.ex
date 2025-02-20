defmodule Front.Models.Queue do
  require Logger

  defstruct [
    :id,
    :name,
    :scope,
    :type,
    :html_url,
    :latest_pipeline,
    :latest_hook
  ]

  alias InternalApi.Plumber.ListGroupedRequest
  alias InternalApi.Plumber.PipelineService.Stub
  alias InternalApi.Plumber.ResponseStatus.ResponseCode

  @spec list_with_latest_pipeline(String.t()) :: [Front.Models.Queue] | nil
  def list_with_latest_pipeline(project_id) do
    Watchman.benchmark("list_queues.duration", fn ->
      req =
        ListGroupedRequest.new(
          project_id: project_id,
          queue_type: [
            InternalApi.Plumber.QueueType.value(:USER_GENERATED)
          ]
        )

      {:ok, response} = Stub.list_grouped(channel(), req, options())

      case ResponseCode.key(response.response_status.code) do
        :OK ->
          Enum.map(response.pipelines, fn pipeline ->
            queue = construct(pipeline.queue, project_id)

            %{queue | latest_pipeline: Front.Models.Pipeline.construct(pipeline)}
          end)

        :BAD_PARAM ->
          Logger.error("Plumber.ListGrouped error. Response: #{inspect(response)}")
          nil
      end
    end)
  end

  def preload_latest_hooks(queues) do
    hook_ids = Enum.map(queues, fn q -> q.latest_pipeline.hook_id end)
    hooks = Front.Models.RepoProxy.find(hook_ids)

    queues
    |> Enum.map(fn queue ->
      hook = Enum.find(hooks, fn h -> h.id == queue.latest_pipeline.hook_id end)

      %{queue | latest_hook: hook}
    end)
  end

  defp construct(queue, project_id) do
    %__MODULE__{
      id: queue.name,
      name: queue.name,
      scope: queue.scope,
      type: queue.type,
      html_url: "/projects/#{project_id}/queues/#{queue.name}"
    }
  end

  defp channel do
    endpoint = Application.fetch_env!(:front, :pipeline_api_grpc_endpoint)

    {:ok, ch} = GRPC.Stub.connect(endpoint)

    ch
  end

  def options, do: [timeout: 30_000]
end
