defmodule HooksProcessor.Hooks.Processing.GitWorker do
  @moduledoc """
  It performs all necessary processing for received git hooks, creates
  branches data and triggers workflow creation on Plumber.
  """
  use GenServer, restart: :transient

  alias HooksProcessor.Hooks.Model.HooksQueries
  alias HooksProcessor.Hooks.Payload.Git, as: GitPayload

  alias HooksProcessor.Clients.{
    ProjectHubClient,
    BranchClient,
    WorkflowClient,
    UserClient,
    RBACClient
  }

  alias LogTee, as: LT

  import HooksProcessor.Hooks.Processing.Utils, only: [whitelisted?: 3]

  def start_link(id) do
    name = {:via, Registry, {WorkersRegistry, "git_worker-#{id}"}}
    GenServer.start_link(__MODULE__, id, name: name)
  end

  def init(id) do
    send(self(), :process_hook)

    {:ok, %{id: id}}
  end

  def handle_info(:process_hook, state = %{id: id}) do
    id |> HooksQueries.get_by_id() |> do_processing(state)
  end

  defp do_processing({:ok, webhook}, state) do
    with {:ok, project} <- ProjectHubClient.describe_project(webhook.project_id),
         hook_type <- GitPayload.hook_type(webhook.request),
         email <- GitPayload.extract_author_email(webhook.request),
         requester_id <- get_requester_id(webhook, email),
         requester_id <- filter_membership(webhook, webhook.organization_id, requester_id),
         {:ok, _webhook} <-
           process_webhook(hook_type, webhook, project.repository, requester_id) do
      "Processing finished successfully." |> graceful_exit(state)
    else
      error -> graceful_exit(error, state)
    end
  end

  defp do_processing({:error, error}, state) do
    "Failed to load webhook from database: '#{to_str(error)}'" |> restart(state)
  end

  defp get_requester_id(webhook, email) do
    "email: #{email}"
    |> LT.info("Hook #{webhook.id} - calling User API to find requester")

    case UserClient.describe_by_email(email) do
      {:ok, user} ->
        user.id

      error ->
        error
        |> LT.warn("Hook #{webhook.id} - requester describe failed: ")

        ""
    end
  end

  defp filter_membership(_, _, ""), do: ""

  defp filter_membership(webhook, organization_id, user_id) do
    "organization_id: #{organization_id}, user_id: #{user_id}"
    |> LT.info("Hook #{webhook.id} - calling RBAC API to check membership")

    case RBACClient.member?(organization_id, user_id) do
      {:ok, true} ->
        user_id

      {:ok, false} ->
        ""

      error ->
        error
        |> LT.warn("Hook #{webhook.id} - member check failed: ")

        ""
    end
  end

  defp process_webhook("branch", webhook, repository, requester_id) do
    with parsed_data <- GitPayload.extract_data(webhook.request, "branch"),
         parsed_data <- Map.put(parsed_data, :requester_id, requester_id),
         parsed_data <- Map.put(parsed_data, :yml_file, repository.pipeline_file),
         parsed_data <- Map.put(parsed_data, :owner, repository.owner),
         parsed_data <- Map.put(parsed_data, :repo_name, repository.name),
         parsed_data <- Map.put(parsed_data, :provider, "git"),
         {:skip_ci, false} <- GitPayload.skip_ci_flag?(parsed_data),
         {:build, true} <- should_build?(repository, parsed_data, :BRANCHES) do
      perform_actions(webhook, parsed_data)
    else
      {:skip_ci, true, parsed_data} ->
        HooksQueries.update_webhook(webhook, parsed_data, "skip_ci")

      {:build, {false, hook_state}, parsed_data} ->
        HooksQueries.update_webhook(webhook, parsed_data, hook_state)

      error ->
        error
    end
  end

  defp process_webhook("tag", webhook, repository, requester_id) do
    with parsed_data <- GitPayload.extract_data(webhook.request, "tag"),
         parsed_data <- Map.put(parsed_data, :yml_file, repository.pipeline_file),
         parsed_data <- Map.put(parsed_data, :owner, repository.owner),
         parsed_data <- Map.put(parsed_data, :repo_name, repository.name),
         parsed_data <- Map.put(parsed_data, :requester_id, requester_id),
         parsed_data <- Map.put(parsed_data, :provider, "git"),
         {:skip_ci, false} <- GitPayload.skip_ci_flag?(parsed_data),
         {:build, true} <- should_build?(repository, parsed_data, :TAGS) do
      perform_actions(webhook, parsed_data)
    else
      {:skip_ci, true, parsed_data} ->
        HooksQueries.update_webhook(webhook, parsed_data, "skip_ci")

      {:build, {false, hook_state}, parsed_data} ->
        HooksQueries.update_webhook(webhook, parsed_data, hook_state)

      error ->
        error
    end
  rescue
    e -> e
  end

  defp process_webhook(hook_type, webhook, _project, requester_id) do
    params = %{provider: "git", requester_id: requester_id}
    HooksQueries.update_webhook(webhook, params, "failed", "BAD REQUEST")

    {:error, "Unsupported type of the hook: '#{hook_type}' for webhook: #{inspect(webhook)}"}
  end

  defp perform_actions(webhook, parsed_data) do
    with {:ok, branch} <- BranchClient.find_or_create(webhook, parsed_data),
         parsed_data <- Map.put(parsed_data, :branch_id, branch.id),
         {:ok, workflow} <- WorkflowClient.schedule_workflow(webhook, parsed_data),
         update_params <- form_update_params(parsed_data, branch, workflow) do
      HooksQueries.update_webhook(webhook, update_params, "launching")
    end
  end

  defp form_update_params(parsed_data, branch, workflow) do
    parsed_data
    |> Map.put(:branch_id, branch.id)
    |> Map.put(:wf_id, workflow.wf_id)
    |> Map.put(:ppl_id, workflow.ppl_id)
  end

  defp should_build?(repository, hook_data, hook_type) do
    cond do
      hook_type not in repository.run_on ->
        {:build, {false, hook_state(hook_type, :skip)}, hook_data}

      not whitelisted?(repository.whitelist, hook_data, hook_type) ->
        {:build, {false, hook_state(hook_type, :whitelist)}, hook_data}

      true ->
        {:build, true}
    end
  end

  defp hook_state(:BRANCHES, :skip), do: "skip_branch"
  defp hook_state(:BRANCHES, :whitelist), do: "whitelist_branch"
  defp hook_state(:TAGS, :skip), do: "skip_tag"
  defp hook_state(:TAGS, :whitelist), do: "whitelist_tag"

  defp graceful_exit(message, state) do
    message
    |> LT.info("Hook #{state.id} - git worker process exits: ")

    {:stop, :normal, state}
  end

  defp restart(error, state) do
    error
    |> LT.warn("Hook #{state.id} - git worker process failiure: ")

    {:stop, :restart, state}
  end

  defp to_str(term) when is_binary(term), do: term
  defp to_str(term), do: inspect(term)
end
