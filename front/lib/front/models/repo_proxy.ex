defmodule Front.Models.RepoProxy do
  require Logger

  alias Front.Utils
  alias InternalApi.RepoProxy
  alias InternalApi.RepoProxy.RepoProxyService.Stub
  alias InternalApi.ResponseStatus

  defstruct [
    :id,
    :type,
    :name,
    :repo_host_avatar_url,
    :repo_host_username,
    :commit_message,
    :commit_author,
    :repo_host_url,
    :head_commit_sha,
    :user_id,
    :pr_mergeable,
    :pr_number,
    :pr_sha,
    :tag_name,
    :branch_name,
    :pr_branch_name,
    :forked_pr
  ]

  @version :crypto.hash(:md5, File.read(__ENV__.file) |> elem(1)) |> Base.encode64()
  def version, do: @version

  def encode(model), do: :erlang.term_to_binary(model)
  def decode(model), do: Plug.Crypto.non_executable_binary_to_term(model, [:safe])
  def cache_key(id), do: "repo-proxy-model/#{@version}/#{id}"

  def find(id), do: find(id, nil)

  def find(ids, _tracing_headers) when is_list(ids) do
    Watchman.benchmark("fetch_many_repo_proxy.duration", fn ->
      get_cached_hooks(ids)
      |> fetch_missing_from_api(ids)
      |> sort_in_requested_order(ids)
    end)
  end

  def find(id, tracing_headers) do
    Watchman.benchmark("fetch_repo_proxy.duration", fn ->
      Cacheman.fetch(:front, cache_key(id), [ttl: :timer.hours(1)], fn ->
        request = %RepoProxy.DescribeRequest{hook_id: id}

        {:ok, response} = Stub.describe(channel(), request, options(tracing_headers))

        case ResponseStatus.Code.key(response.status.code) do
          :OK ->
            {:ok, response.hook |> construct() |> encode()}

          _ ->
            Utils.log_verbose("RepoProxy#find #{id}: #{inspect(response)}")
            nil
        end
      end)
      |> case do
        {:ok, encoded} ->
          encoded |> decode()

        nil ->
          nil
      end
    end)
  end

  def create(project_id, requester_id, request_token, integration_type \\ "github_oauth_token") do
    Watchman.benchmark("repo_proxy.create.duration", fn ->
      request =
        RepoProxy.CreateRequest.new(
          request_token: request_token,
          project_id: project_id,
          requester_id: requester_id,
          triggered_by: InternalApi.PlumberWF.TriggeredBy.value(:API),
          git: RepoProxy.CreateRequest.Git.new(reference: "refs/heads/fork-and-run")
        )

      case Stub.create(channel(integration_type), request, options(nil)) do
        {:ok, response} ->
          {:ok,
           %{
             hook_id: response.hook_id,
             workflow_id: response.workflow_id,
             pipeline_id: response.pipeline_id
           }}

        {:error, error} ->
          {:error, error}
      end
    end)
  end

  def list_blocked(project_id, name_contains \\ "") do
    Watchman.benchmark("repo_proxy.list_blocked.duration", fn ->
      request =
        RepoProxy.ListBlockedHooksRequest.new(
          project_id: project_id,
          git_ref: name_contains
        )

      case Stub.list_blocked_hooks(channel(), request, options()) do
        {:ok, response} ->
          Utils.log_verbose("Received response from RepoProxy: #{inspect(response)}")

          case ResponseStatus.Code.key(response.status.code) do
            :OK -> construct(response.hooks)
            _ -> nil
          end

        {:error, error} ->
          Watchman.increment("external.repoproxy.listblocked.failed")
          Utils.log_verbose("#{project_id}: Hook is nil: #{inspect(error)}")

          nil
      end
    end)
  end

  def build_blocked(project_id, hook_id, tracing_headers \\ nil) do
    Watchman.benchmark("repo_proxy.build_blocked.duration", fn ->
      request = RepoProxy.ScheduleBlockedHookRequest.new(project_id: project_id, hook_id: hook_id)

      case Stub.schedule_blocked_hook(channel(), request, options(tracing_headers)) do
        {:ok, response} ->
          Utils.log_verbose("Received response from RepoProxy: #{inspect(response)}")

          case ResponseStatus.Code.key(response.status.code) do
            :OK -> {:ok, %{workflow_id: response.wf_id}}
            _ -> {:error, "Schedule Error"}
          end

        {:error, error} ->
          Watchman.increment("external.repoproxy.listblocked.failed")
          Utils.log_verbose("#{project_id}: Hook is nil: #{inspect(error)}")

          {:error, "Internal Error"}
      end
    end)
  end

  defp construct(proxies) when is_list(proxies) do
    proxies |> Enum.map(fn proxy -> construct(proxy) end)
  end

  defp construct(proxy) do
    key =
      InternalApi.RepoProxy.Hook.Type.key(proxy.git_ref_type)
      |> Atom.to_string()
      |> String.downcase()

    name =
      case key do
        "branch" -> proxy.branch_name
        "tag" -> proxy.tag_name
        "pr" -> proxy.pr_name
      end

    %__MODULE__{
      id: proxy.hook_id,
      type: key,
      name: name,
      repo_host_avatar_url: proxy.repo_host_avatar_url,
      repo_host_username: proxy.repo_host_username,
      commit_message: proxy.commit_message,
      commit_author: proxy.commit_author,
      repo_host_url: proxy.repo_host_url,
      head_commit_sha: proxy.head_commit_sha,
      user_id: proxy.user_id,
      pr_mergeable: proxy.pr_mergeable,
      pr_number: proxy.pr_number,
      pr_sha: proxy.pr_sha,
      tag_name: proxy.tag_name,
      branch_name: proxy.branch_name,
      pr_branch_name: proxy.pr_branch_name,
      forked_pr: forked_pr(key, proxy.repo_slug, proxy.pr_slug)
    }
  end

  defp channel(integration_type \\ "github_oauth_token")
  # should be used only temporarly for create hook action
  defp channel(integration_type) when integration_type in [:BITBUCKET, :GITLAB, :GIT] do
    case GRPC.Stub.connect(Application.fetch_env!(:front, :hooks_grpc_endpoint)) do
      {:ok, channel} -> channel
      _ -> nil
    end
  end

  defp channel(_) do
    case GRPC.Stub.connect(Application.fetch_env!(:front, :repo_proxy_grpc_endpoint)) do
      {:ok, channel} -> channel
      # raise error ?
      _ -> nil
    end
  end

  defp forked_pr("pr", slug1, slug2) when slug1 != slug2, do: true
  defp forked_pr(_, _, _), do: false

  defp get_cached_hooks(ids) do
    Watchman.benchmark("get_cached_hooks.duration", fn ->
      ids
      |> Utils.parallel_map(fn id ->
        case Cacheman.get(:front, cache_key(id)) do
          {:ok, nil} -> nil
          {:ok, encoded} -> decode(encoded)
        end
      end)
      |> Enum.reject(&is_nil/1)
    end)
  end

  defp fetch_missing_from_api(cached, ids) do
    Watchman.benchmark("fetch_missing_from_api.duration", fn ->
      missing_ids = ids_missing_in_cache(cached, ids)

      if missing_ids |> Enum.empty?() do
        cached
      else
        cached |> Enum.concat(missing_ids |> describe_many())
      end
    end)
  end

  def ids_missing_in_cache(cached, ids) do
    ids
    |> Enum.filter(fn id -> !Enum.any?(cached, fn hook -> hook.id == id end) end)
  end

  def invalidate(id) do
    cache_key(id)
    |> then(&Cacheman.delete(:front, &1))
  end

  defp sort_in_requested_order(hooks, ids) do
    ids
    |> Enum.map(fn id ->
      hooks |> Enum.find(fn hook -> hook.id == id end)
    end)
    |> Enum.filter(& &1)
  end

  defp describe_many(ids) do
    Watchman.benchmark("describe_many_repo_proxy.duration", fn ->
      request = %RepoProxy.DescribeManyRequest{hook_ids: ids}

      {:ok, response} =
        Stub.describe_many(
          channel(),
          request,
          timeout: 30_000
        )

      Logger.debug(fn ->
        "Received response from RepoProxy: #{inspect(response)}"
      end)

      hooks =
        case ResponseStatus.Code.key(response.status.code) do
          :OK -> construct(response.hooks)
        end

      hooks
      |> Enum.each(fn hook ->
        Cacheman.put(:front, cache_key(hook.id), encode(hook))
      end)

      hooks
    end)
  end

  defp options(tracing_headers \\ nil), do: [timeout: 30_000, metadata: tracing_headers]
end
