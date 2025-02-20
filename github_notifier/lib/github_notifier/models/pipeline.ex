defmodule GithubNotifier.Models.Pipeline do
  defstruct [
    :id,
    :workflow_id,
    :state,
    :result,
    :blocks,
    :project_id,
    :sha,
    :hook_id,
    :created_at,
    :yaml_file_path,
    :name
  ]

  require Logger

  alias InternalApi.Plumber.ResponseStatus.ResponseCode
  alias InternalApi.Plumber.Pipeline.State, as: PipelineState
  alias InternalApi.Plumber.Pipeline.Result, as: PipelineResult
  alias InternalApi.Plumber.Block.State, as: BlockState
  alias InternalApi.Plumber.Block.Result, as: BlockResult

  @spec find(String.t()) :: GithubNotifier.Models.Pipeline | nil
  def find(id) do
    Watchman.benchmark("fetch_pipeline.duration", fn ->
      req =
        InternalApi.Plumber.DescribeRequest.new(
          ppl_id: id,
          detailed: true
        )

      {:ok, channel} =
        GRPC.Stub.connect(Application.get_env(:github_notifier, :pipeline_grpc_endpoint))

      Logger.debug(fn ->
        "Sending Pipeline describe request for pipeline_id: #{id}"
      end)

      Logger.debug(inspect(req))

      {:ok, describe_response} =
        InternalApi.Plumber.PipelineService.Stub.describe(channel, req, timeout: 30_000)

      Logger.debug("Received Pipeline describe response")
      Logger.debug(inspect(describe_response))

      case ResponseCode.key(describe_response.response_status.code) do
        :OK -> construct(describe_response)
        :BAD_PARAM -> nil
      end
    end)
  end

  defp construct(response) do
    %__MODULE__{
      id: response.pipeline.ppl_id,
      state: PipelineState.key(response.pipeline.state),
      result: PipelineResult.key(response.pipeline.result),
      blocks: construct_blocks(response.blocks),
      project_id: response.pipeline.project_id,
      workflow_id: response.pipeline.wf_id,
      sha: response.pipeline.commit_sha,
      hook_id: response.pipeline.hook_id,
      created_at: response.pipeline.created_at.seconds,
      yaml_file_path:
        yaml_file_path(response.pipeline.working_directory, response.pipeline.yaml_file_name),
      name: response.pipeline.name
    }
  end

  def yaml_file_path(".", file_name), do: file_name

  def yaml_file_path(dir, file_name) do
    Enum.join([dir, file_name], "/")
  end

  defp construct_blocks(blocks) do
    Enum.map(blocks, fn block ->
      %{
        id: block.block_id,
        name: block.name,
        state: BlockState.key(block.state),
        result: BlockResult.key(block.result)
      }
    end)
  end
end
