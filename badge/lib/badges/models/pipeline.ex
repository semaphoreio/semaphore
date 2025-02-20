defmodule Badges.Models.Pipeline do
  defstruct [:id, :state, :result, :reason]

  require Logger

  def find(project_id, branch, pipeline_file) do
    Watchman.benchmark("fetch_pipeline.duration", fn ->
      req =
        InternalApi.Plumber.ListKeysetRequest.new(
          page_size: 1,
          project_id: project_id,
          yml_file_path: pipeline_file,
          label: branch,
          git_ref_types: [InternalApi.Plumber.GitRefType.value(:BRANCH)]
        )

      case InternalApi.Plumber.PipelineService.Stub.list_keyset(channel(), req, options()) do
        {:ok, res} -> construct(res.pipelines)
        _ -> nil
      end
    end)
  end

  defp construct(pipelines) when not is_list(pipelines) or pipelines == [], do: nil

  defp construct([pipeline | _]) do
    %__MODULE__{
      id: pipeline.ppl_id,
      state: pipeline.state,
      result: pipeline.result,
      reason: pipeline.result_reason
    }
  end

  defp channel do
    {:ok, ch} = GRPC.Stub.connect(Application.fetch_env!(:badges, :plumber_grpc_endpoint))
    ch
  end

  defp options do
    [timeout: 30_000]
  end
end
