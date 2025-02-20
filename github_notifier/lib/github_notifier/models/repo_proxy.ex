defmodule GithubNotifier.Models.RepoProxy do
  require Logger

  alias InternalApi.RepoProxy.DescribeRequest
  alias InternalApi.RepoProxy.RepoProxyService.Stub
  alias InternalApi.ResponseStatus

  defstruct [
    :id,
    :pr_sha,
    :git_ref_type,
    :build_sha,
    :branch_name
  ]

  @spec find(String.t()) :: [ProjectPage.Models.RepoProxy] | nil
  def find(id, tracing_headers \\ nil) do
    Watchman.benchmark("fetch_hook.duration", fn ->
      request = %DescribeRequest{hook_id: id}

      Logger.debug(fn -> "Sending describe hook request: #{inspect(request)}" end)
      {:ok, response} = Stub.describe(channel(), request, options(tracing_headers))
      Logger.debug(fn -> "Received describe response from hook: #{inspect(response)}" end)

      case ResponseStatus.Code.key(response.status.code) do
        :OK -> construct(response.hook)
        _ -> nil
      end
    end)
  end

  defp construct(hook) do
    %__MODULE__{
      id: hook.hook_id,
      pr_sha: hook.pr_sha,
      git_ref_type: hook.git_ref_type,
      build_sha: hook.head_commit_sha,
      branch_name: hook.branch_name
    }
  end

  defp channel do
    case GRPC.Stub.connect(Application.fetch_env!(:github_notifier, :hook_api_grpc_endpoint)) do
      {:ok, channel} -> channel
      # raise error ?
      _ -> nil
    end
  end

  def options(tracing_headers), do: [timeout: 30_000, metadata: tracing_headers]
end
