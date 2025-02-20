defmodule HooksProcessor.Hooks.Grpc.Server do
  @moduledoc """
  GRPC server which exposes RepoProxy API
  """
  use GRPC.Server, service: InternalApi.RepoProxy.RepoProxyService.Service
  use Sentry.Grpc, service: InternalApi.RepoProxy.RepoProxyService.Service

  alias Util.{Metrics, ToTuple}
  alias HooksProcessor.Hooks.Model.HooksQueries
  alias HooksProcessor.Hooks.Payload.Api, as: ApiPayload
  alias HooksProcessor.Clients.{UserClient, ProjectHubClient, BranchClient, WorkflowClient, RepositoryClient}
  alias InternalApi.RepoProxy.{CreateResponse, CreateBlankResponse}

  def describe(_, _) do
    raise GRPC.RPCError, status: GRPC.Status.unimplemented(), message: "Not yet implemented!"
  end

  def describe_many(_, _) do
    raise GRPC.RPCError, status: GRPC.Status.unimplemented(), message: "Not yet implemented!"
  end

  def list_blocked_hooks(_, _) do
    raise GRPC.RPCError, status: GRPC.Status.unimplemented(), message: "Not yet implemented!"
  end

  def schedule_blocked_hook(_, _) do
    raise GRPC.RPCError, status: GRPC.Status.unimplemented(), message: "Not yet implemented!"
  end

  def create(request, _), do: create_hook(:create, request)
  def create_blank(request, _), do: create_hook(:create_blank, request)

  defp create_hook(rpc, request) do
    Metrics.benchmark("HooksProcessor.Api", [to_string(rpc)], fn ->
      with {:ok, project} <- ProjectHubClient.describe_project(request.project_id),
           {:ok, commit} <-
             RepositoryClient.describe_revision(project.repository.id, request.git.reference, request.git.commit_sha),
           {:ok, user} <- UserClient.describe(request.requester_id),
           {:ok, hook_data} <- hook_data(rpc, project, commit, user, request),
           {:ok, hook} <- HooksQueries.insert(hook_data),
           hook_type <- ApiPayload.hook_type(hook.request),
           {:ok, hook} <- process_hook(rpc, hook_type, hook, project.repository, user.id) do
        form_response(rpc, hook)
      else
        error ->
          raise GRPC.RPCError,
            status: GRPC.Status.invalid_argument(),
            message: error
      end
    end)
  end

  defp process_hook(rpc, hook_type, webhook, repository, requester_id) when hook_type in ["tag", "branch"] do
    with parsed_data <- ApiPayload.extract_data(webhook.request),
         parsed_data <- Map.put(parsed_data, :yml_file, repository.pipeline_file),
         parsed_data <- Map.put(parsed_data, :requester_id, requester_id),
         parsed_data <- Map.put(parsed_data, :provider, provider(repository.integration_type)) do
      perform_actions(rpc, webhook, parsed_data)
    end
  end

  defp perform_actions(:create, webhook, parsed_data) do
    with {:ok, branch} <- BranchClient.find_or_create(webhook, parsed_data),
         parsed_data <- Map.put(parsed_data, :branch_id, branch.id),
         {:ok, workflow} <- WorkflowClient.schedule_workflow(webhook, parsed_data, :API),
         update_params <- form_update_params(parsed_data, branch, workflow) do
      HooksQueries.update_webhook(webhook, update_params, "launching")
    end
  end

  defp perform_actions(:create_blank, webhook, parsed_data) do
    with {:ok, branch} <- BranchClient.find_or_create(webhook, parsed_data),
         parsed_data <- Map.put(parsed_data, :branch_id, branch.id),
         update_params <- form_update_params(parsed_data, branch) do
      HooksQueries.update_webhook(webhook, update_params, "launching")
    end
  end

  defp form_update_params(parsed_data, branch) do
    parsed_data
    |> Map.put(:branch_id, branch.id)
    |> Map.delete(:provider)
  end

  defp form_update_params(parsed_data, branch, workflow) do
    parsed_data
    |> Map.put(:branch_id, branch.id)
    |> Map.put(:wf_id, workflow.wf_id)
    |> Map.put(:ppl_id, workflow.ppl_id)
    |> Map.delete(:provider)
  end

  defp hook_data(:create, project, commit, user, request) do
    %{
      received_at: DateTime.utc_now(),
      webhook: webhook_data(commit, user, project.repository, request.git.reference),
      project_id: project.id,
      provider: "api",
      repository_id: project.repository.id,
      organization_id: project.org_id
    }
    |> ToTuple.ok()
  end

  defp hook_data(:create_blank, project, commit, user, request) do
    %{
      received_at: DateTime.utc_now(),
      webhook: webhook_data(commit, user, project.repository, request.git.reference),
      project_id: project.id,
      provider: "api",
      repository_id: project.repository.id,
      organization_id: project.org_id,
      wf_id: request.wf_id,
      ppl_id: request.pipeline_id
    }
    |> ToTuple.ok()
  end

  defp webhook_data(commit, user, repository, reference) do
    %{
      "commit" => %{
        "sha" => commit.sha,
        "message" => commit.msg,
        "author_name" => commit.author_name,
        "author_uuid" => commit.author_uuid,
        "author_avatar_url" => commit.author_avatar_url
      },
      "pusher" => %{
        "name" => user.name,
        "email" => user.email
      },
      "repository" => %{
        "html_url" => repo_html_url(repository),
        "full_name" => "#{repository.owner}/#{repository.name}",
        "owner" => repository.owner,
        "name" => repository.name
      },
      "reference" => reference
    }
  end

  defp repo_html_url(repository = %{integration_type: :GITHUB_OAUTH_TOKEN}), do: repo_html_url(:github, repository)
  defp repo_html_url(repository = %{integration_type: :GITHUB_APP}), do: repo_html_url(:github, repository)
  defp repo_html_url(repository = %{integration_type: :BITBUCKET}), do: repo_html_url(:bitbucket, repository)

  defp repo_html_url(:github, repository), do: "https://github.com/#{repository.owner}/#{repository.name}"
  defp repo_html_url(:bitbucket, repository), do: "https://bitbucket.org/#{repository.owner}/#{repository.name}"

  defp form_response(:create, hook) do
    %CreateResponse{
      hook_id: hook.id,
      workflow_id: hook.wf_id,
      pipeline_id: hook.ppl_id
    }
  end

  defp form_response(:create_blank, hook) do
    git_reference = get_in(hook.request, ["reference"])

    branch_name =
      if String.starts_with?(git_reference, "refs/heads/"),
        do: String.replace(git_reference, "refs/heads/", ""),
        else: git_reference

    %CreateBlankResponse{
      hook_id: hook.id,
      wf_id: hook.wf_id,
      pipeline_id: hook.ppl_id,
      branch_id: hook.branch_id,
      repo: %{
        owner: get_in(hook.request, ["repository", "owner"]),
        repo_name: get_in(hook.request, ["repository", "name"]),
        branch_name: branch_name,
        commit_sha: get_in(hook.request, ["commit", "sha"]),
        repository_id: hook.repository_id
      }
    }
  end

  defp provider(:GITHUB_OAUTH_TOKEN), do: "github"
  defp provider(:GITHUB_APP), do: "github"
  defp provider(:BITBUCKET), do: "bitbucket"
end
