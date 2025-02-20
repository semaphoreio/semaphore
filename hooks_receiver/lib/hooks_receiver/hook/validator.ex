defmodule HooksReceiver.Hook.Validator do
  alias Util.ToTuple
  require Logger

  @moduledoc """
  This modules performs the following webhook payload checks before returning 200:
  - check if hook type is supported
  - check if repository exists
  - check if org is blocked
  """
  def run(provider, req_headers, params) do
    with {:ok, org_id} <- extract_org_id(req_headers),
         {:ok, repository_id} <- extract_repository_id(params),
         check_signature <- Task.async(fn -> extract_signature(req_headers) end),
         check_org <- Task.async(fn -> org_eligible?(org_id) end),
         check_project <- Task.async(fn -> extract_project_id(repository_id) end),
         check_hook_type <- Task.async(fn -> hook_supported?(provider, req_headers) end),
         {true, project_id} <- Task.await(check_project),
         true <- Task.await(check_hook_type),
         {:ok, signature} <- Task.await(check_signature),
         {true, _org_id} <- Task.await(check_org) do
      hook_metadata = %{
        org_id: org_id,
        project_id: project_id,
        repository_id: repository_id,
        webhook: params,
        signature: signature
      }

      {true, hook_metadata}
    else
      result ->
        result
        |> tap(fn result ->
          Logger.error("Hook processing is halted with the result: #{inspect(result)}")
        end)
        |> ToTuple.error()

        false
    end
  end

  defp extract_signature(req_headers) do
    req_headers
    |> Enum.into(%{})
    |> case do
      %{"x-hub-signature" => signature} ->
        {:ok, signature}

      %{"x-gitlab-token" => signature} ->
        {:ok, signature}

      _ ->
        {:ok, ""}
    end
  end

  defp extract_project_id(repository_id) do
    case HooksReceiver.RepositoryClient.describe(repository_id) do
      {:ok, repository} -> {true, repository.project_id}
      {:error, _result} -> {false, :invalid_repository}
    end
  end

  defp hook_supported?(:bitbucket, req_headers) do
    case HooksReceiver.Hook.BitbucketFilter.supported?(req_headers) do
      true -> true
      false -> {false, :unsupported_hook}
    end
  end

  defp hook_supported?(:gitlab, req_headers) do
    case HooksReceiver.Hook.GitlabFilter.supported?(req_headers) do
      true -> true
      false -> {false, :unsupported_hook}
    end
  end

  defp hook_supported?(:git, _req_headers), do: true

  defp org_eligible?(org_id) do
    with {:ok, org_response} <- HooksReceiver.OrganizationClient.describe(org_id),
         false <- org_response.suspended do
      {true, org_response.org_id}
    else
      {:error, _result} -> {false, :invalid_organization}
      true -> {false, :org_suspended}
    end
  end

  defp extract_org_id(req_headers) do
    case req_headers |> Enum.into(%{}) |> Map.get("x-semaphore-org-id") do
      nil -> {:error, :invalid_org_id}
      org_id -> {:ok, org_id}
    end
  end

  defp extract_repository_id(params) do
    case params |> Enum.into(%{}) |> Map.get("id") do
      nil -> {:error, :invalid_repository_id}
      repository_id -> {:ok, repository_id}
    end
  end
end
