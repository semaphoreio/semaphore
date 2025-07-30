defmodule HooksProcessor.Hooks.Processing.Utils do
  @moduledoc """
  Utility functions for processing hooks.
  """
  alias HooksProcessor.Clients.{AdminClient, BranchClient, WorkflowClient, UserClient}
  alias HooksProcessor.Hooks.Model.HooksQueries
  alias LogTee, as: LT

  def schedule_workflow(webhook, parsed_data) do
    with {:ok, branch} <- BranchClient.find_or_create(webhook, parsed_data),
         parsed_data <- Map.put(parsed_data, :branch_id, branch.id),
         {:ok, workflow} <- WorkflowClient.schedule_workflow(webhook, parsed_data),
         update_params <- form_update_params(parsed_data, branch, workflow) do
      HooksQueries.update_webhook(webhook, update_params, "launching")
    end
  end

  def update_to_deleting_branch(webhook, parsed_data) do
    with {:ok, branch} <- BranchClient.describe(webhook, parsed_data),
         :ok <- AdminClient.terminate_all_pipelines(webhook.project_id, branch.name, :BRANCH_DELETION),
         parsed_data <- Map.put(parsed_data, :branch_id, branch.id),
         {:ok, _message} <- BranchClient.archive(branch.id, webhook) do
      HooksQueries.update_webhook(webhook, parsed_data, "deleting_branch")
    else
      {:error, :not_found} ->
        HooksQueries.update_webhook(webhook, parsed_data, "deleting_branch")

      error ->
        error
    end
  end

  defp form_update_params(parsed_data, branch, workflow) do
    parsed_data
    |> Map.put(:branch_id, branch.id)
    |> Map.put(:wf_id, workflow.wf_id)
    |> Map.put(:ppl_id, workflow.ppl_id)
  end

  def get_requester_id(webhook, provider_uid, provider_type) do
    "provider_uid: #{provider_uid} for provider: #{provider_type}"
    |> LT.debug("Hook #{webhook.id} - calling User API to find requester")

    case UserClient.describe_by_repository_provider(provider_uid, provider_type) do
      {:ok, user} ->
        user.id

      error ->
        error |> LT.warn("Hook #{webhook.id} - requester describe failed: ")
        ""
    end
  end

  def whitelisted?(whitelist, %{display_name: ref_name}, hook_type) do
    hook_type_lc = hook_type |> Atom.to_string() |> String.downcase() |> String.to_atom()

    whitelist
    |> Map.get(hook_type_lc)
    |> add_catch_all_if_empty()
    |> Enum.reduce(false, fn pattern, acc ->
      if pattern_match?(pattern, ref_name), do: true, else: acc
    end)
  end

  defp add_catch_all_if_empty([]), do: ["/.*/"]
  defp add_catch_all_if_empty(list), do: list

  defp pattern_match?(pattern, ref_name) do
    if String.starts_with?(pattern, "/") and String.ends_with?(pattern, "/") do
      pattern = String.slice(pattern, 1..-2//1)
      Regex.match?(~r/#{pattern}/, ref_name)
    else
      pattern == ref_name
    end
  end
end
