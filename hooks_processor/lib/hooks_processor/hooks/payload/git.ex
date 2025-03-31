defmodule HooksProcessor.Hooks.Payload.Git do
  @moduledoc """
  Encapsulates operations on git hooks payload.
  """

  @doc """
  Extracts hook type from hook payload.
  """

  def hook_type(payload) do
    payload
    |> get_in(["reference"])
    |> case do
      "refs/tags/" <> _ -> "tag"
      "refs/heads/" <> _ -> "branch"
      _ -> ""
    end
  end

  @doc """
  Checks if head commit has [skip ci] flags in commit messsage
  """
  def skip_ci_flag?(data = %{commit_message: message}) do
    if String.contains?(message, "[ci skip]") or String.contains?(message, "[skip ci]") do
      {:skip_ci, true, data}
    else
      {:skip_ci, false}
    end
  end

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
    author = payload |> get_in(["author", "name"])
    email = payload |> get_in(["author", "email"])
    commit_sha = payload |> get_in(["commit", "sha"])
    commit_message = payload |> get_in(["commit", "message"])

    %{
      branch_name: branch_name,
      git_ref: reference,
      display_name: display_name,
      repo_name: "",
      commit_sha: commit_sha,
      commit_message: commit_message,
      commit_author: author,
      author_email: email,
      pr_name: "",
      pr_number: 0
    }
  end

  def extract_author_email(payload) do
    payload
    |> get_in(["actor", "email"])
    |> case do
      nil ->
        ""

      email ->
        email
    end
  end
end
