defmodule HooksProcessor.Hooks.Payload.Api do
  @moduledoc """
  Encapsulates operations on api hooks payload.
  """

  @doc """
  Extracts hook type from hook payload.
  """
  def hook_type(payload), do: type(payload |> Map.get("reference"))

  defp type("refs/tags/" <> _), do: "tag"
  defp type("refs/heads/" <> _), do: "branch"
  defp type("refs/pull/" <> _), do: "pull-request"

  def extract_data(payload), do: extract_data(payload, hook_type(payload))

  def extract_data(payload, "tag") do
    reference = payload |> Map.get("reference")
    "refs/tags/" <> tag_name = reference

    extract_data_(reference, tag_name, payload)
  end

  def extract_data(payload, "branch") do
    reference = payload |> Map.get("reference")
    "refs/heads/" <> branch_name = reference

    extract_data_(branch_name, branch_name, payload)
  end

  defp extract_data_(branch_name, display_name, payload) do
    reference = payload |> Map.get("reference")
    repo_name = payload |> Map.get("repository") |> Map.get("name")
    owner = payload |> Map.get("repository") |> Map.get("owner")
    author = payload |> Map.get("commit") |> Map.get("author_name")
    commit_sha = payload |> Map.get("commit") |> Map.get("sha")
    commit_message = payload |> Map.get("commit") |> Map.get("message")

    %{
      branch_name: branch_name,
      git_ref: reference,
      display_name: display_name,
      owner: owner,
      repo_name: repo_name,
      commit_sha: commit_sha,
      commit_message: commit_message,
      commit_author: author,
      pr_name: "",
      pr_number: 0
    }
  end
end
