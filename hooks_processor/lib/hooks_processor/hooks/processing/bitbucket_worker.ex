defmodule HooksProcessor.Hooks.Processing.BitbucketWorker do
  @moduledoc """
  It performs all necessarry processing for received bitbucket hooks, creates and
  deletes branches data and triggers workflow creation on Plumber.
  """
  use GenServer, restart: :transient

  alias HooksProcessor.Hooks.Model.HooksQueries
  alias HooksProcessor.Hooks.Payload.Bitbucket, as: BBPayload
  alias HooksProcessor.Clients.ProjectHubClient
  alias LogTee, as: LT

  import HooksProcessor.Hooks.Processing.Utils,
    only: [
      whitelisted?: 3,
      get_requester_id: 3,
      schedule_workflow: 2,
      update_to_deleting_branch: 2
    ]

  def start_link(id) do
    name = {:via, Registry, {WorkersRegistry, "bitbucket_worker-#{id}"}}
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
         hook_type <- BBPayload.hook_type(webhook.request),
         actor_id <- BBPayload.extract_actor_id(webhook.request),
         requester_id <- get_requester_id(webhook, actor_id, "bitbucket"),
         {:ok, _webhook} <-
           process_webhook(hook_type, webhook, project.repository, requester_id) do
      :ok |> graceful_exit(state)
    else
      error -> graceful_exit(error, state)
    end
  end

  defp do_processing({:error, error}, state) do
    "Failed to load webhook from database: '#{to_str(error)}'" |> restart(state)
  end

  defp process_webhook("branch", webhook, repository, requester_id) do
    with action_type <- BBPayload.branch_action(webhook.request),
         parsed_data <- BBPayload.extract_data(webhook.request, "branch", action_type),
         parsed_data <- Map.put(parsed_data, :requester_id, requester_id),
         parsed_data <- Map.put(parsed_data, :yml_file, repository.pipeline_file),
         parsed_data <- Map.put(parsed_data, :provider, "bitbucket"),
         {:skip_ci, false} <- BBPayload.skip_ci_flag?(parsed_data),
         {:build, true} <- should_build?(repository, parsed_data, :BRANCHES) do
      perform_actions(webhook, parsed_data, "branch", action_type)
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
    with parsed_data <- BBPayload.extract_data(webhook.request, "tag", "push"),
         parsed_data <- Map.put(parsed_data, :yml_file, repository.pipeline_file),
         parsed_data <- Map.put(parsed_data, :requester_id, requester_id),
         parsed_data <- Map.put(parsed_data, :provider, "bitbucket"),
         {:skip_ci, false} <- BBPayload.skip_ci_flag?(parsed_data),
         {:build, true} <- should_build?(repository, parsed_data, :TAGS) do
      perform_actions(webhook, parsed_data, "tag", "new")
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

  defp process_webhook(hook_type, _webhook, _project, _requester_id) do
    # Increment unsupported hook type metric
    Watchman.increment({"hooks.processing.bitbucket", ["unsupported_hook"]})

    "Unsuported type of the hook: '#{hook_type}'"
  end

  defp perform_actions(webhook, parsed_data, hook_type, action_type)
       when hook_type in ["branch", "tag"] and action_type in ["new", "push"] do
    schedule_workflow(webhook, parsed_data)
  end

  defp perform_actions(webhook, parsed_data, "branch", "deleted") do
    update_to_deleting_branch(webhook, parsed_data)
  end

  defp should_build?(repository, hook_data, hook_type) do
    cond do
      hook_type not in repository.run_on ->
        # Increment skip configuration metric
        Watchman.increment({"hooks.processing.bitbucket", ["skip", "configuration"]})

        {:build, {false, hook_state(hook_type, :skip)}, hook_data}

      not whitelisted?(repository.whitelist, hook_data, hook_type) ->
        # Increment skip configuration metric
        Watchman.increment({"hooks.processing.bitbucket", ["skip", "whitelist"]})

        {:build, {false, hook_state(hook_type, :whitelist)}, hook_data}

      true ->
        {:build, true}
    end
  end

  defp hook_state(:BRANCHES, :skip), do: "skip_branch"
  defp hook_state(:BRANCHES, :whitelist), do: "whitelist_branch"
  defp hook_state(:TAGS, :skip), do: "skip_tag"
  defp hook_state(:TAGS, :whitelist), do: "whitelist_tag"

  defp graceful_exit(result, state) do
    case result do
      :ok ->
        Watchman.increment({"hooks.processing.bitbucket", ["success"]})

        "Processing finished successfully."
        |> LT.debug("Hook #{state.id} - bitbucket worker process exits: ")

      error ->
        Watchman.increment({"hooks.processing.bitbucket", ["error"]})

        error
        |> LT.error("Hook #{state.id} - bitbucket worker process exits: ")
    end

    {:stop, :normal, state}
  end

  defp restart(error, state) do
    # Increment failure metric
    Watchman.increment({"hooks.processing.bitbucket", ["restart"]})

    error
    |> LT.warn("Hook #{state.id} - bitbucket worker process failiure: ")

    {:stop, :restart, state}
  end

  defp to_str(term) when is_binary(term), do: term
  defp to_str(term), do: inspect(term)
end
