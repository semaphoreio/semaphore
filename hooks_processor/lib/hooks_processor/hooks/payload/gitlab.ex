defmodule HooksProcessor.Hooks.Payload.Gitlab do
  @moduledoc """
  Encapsulates operations on gitlab hooks payload.
  """

  # Null commits is used to determine whether branch was created or deleted
  # In case of deleted branch, null commit is on after field
  # In case of created branch, null commit is on before field
  @null_commit "0000000000000000000000000000000000000000"

  @doc """
  Extracts hook type from hook payload.
  """
  def hook_type(payload), do: payload |> Map.get("object_kind")

  @doc """
  Used for concluding whether branch was created, updated or deleted via given push
  """
  def branch_action(payload) do
    cond do
      Map.get(payload, "before") == @null_commit -> "new"
      Map.get(payload, "after") == @null_commit -> "deleted"
      true -> "push"
    end
  end

  @doc """
  Extracts from payload all data necessary for branch creation and workkflow scheduling
  """
  def extract_data(payload, hook_type, action_type)

  # if deleted branch, then null commit is on after field
  # then the valid commit is on before field
  def extract_data(payload, "push", "deleted") do
    commit_id = Map.get(payload, "before")
    handle_push_commit_id(payload, commit_id)
  end

  # if created branch, then null commit is on before field
  # then the valid commit is on after field
  def extract_data(payload, "push", "new") do
    commit_id = Map.get(payload, "after")
    handle_push_commit_id(payload, commit_id)
  end

  # if normal push, then the valid commit is on checkout_sha field
  def extract_data(payload, "push", "push") do
    commit_id = Map.get(payload, "checkout_sha")
    handle_push_commit_id(payload, commit_id)
  end

  def extract_data(payload, "tag_push", _action_type) do
    project = Map.get(payload, "project")
    tag_ref = Map.get(payload, "ref")
    commits = Map.get(payload, "commits", [])
    tag_name = String.replace(tag_ref, "refs/tags/", "")
    commit_sha = Map.get(payload, "checkout_sha")
    owner = Map.get(project, "namespace")
    repo_name = get_in(payload, ["repository", "name"])
    commit = Enum.find(commits, %{}, fn commit -> commit["id"] == commit_sha end)
    author_name = get_in(commit, ["author", "name"])
    author_email = get_in(commit, ["author", "email"])

    %{
      branch_name: tag_ref,
      git_ref: tag_ref,
      display_name: tag_name,
      owner: owner,
      repo_name: repo_name,
      commit_sha: commit_sha,
      commit_message: Map.get(commit, "message", ""),
      commit_author: author_name,
      author_email: author_email,
      pr_name: "",
      pr_number: 0
    }
  end

  def extract_data(payload, "merge_request", _action_type) do
    object_attributes = Map.get(payload, "object_attributes")
    last_commit = Map.get(object_attributes, "last_commit")
    pr_name = Map.get(object_attributes, "title")
    pr_number = Map.get(object_attributes, "iid")
    repository = Map.get(payload, "repository")
    branch_name = Map.get(object_attributes, "source_branch")
    owner = get_in(object_attributes, ["source", "namespace"])

    %{
      branch_name: branch_name,
      git_ref: "refs/heads/" <> branch_name,
      display_name: branch_name,
      owner: owner,
      repo_name: Map.get(repository, "name"),
      commit_sha: Map.get(last_commit, "id"),
      commit_message: Map.get(last_commit, "message"),
      commit_author: get_in(last_commit, ["author", "name"]) || "",
      author_email: get_in(last_commit, ["author", "email"]) || "",
      pr_name: pr_name,
      pr_number: pr_number
    }
  end

  defp handle_push_commit_id(payload, commit_id) do
    payload
    |> Map.put("commit_id", commit_id)
    |> do_push_extract_data()
  end

  defp do_push_extract_data(payload) do
    commit_id = Map.get(payload, "commit_id")
    commits = Map.get(payload, "commits", [])
    project = Map.get(payload, "project")
    ref = Map.get(payload, "ref")
    latest_commit = Enum.find(commits, %{}, fn commit -> commit["id"] == commit_id end)
    author = Map.get(latest_commit, "author", %{})
    branch_name = String.replace(ref, "refs/heads/", "")
    owner = Map.get(project, "namespace")
    repo_name = get_in(payload, ["repository", "name"])

    %{
      branch_name: branch_name,
      git_ref: ref,
      display_name: branch_name,
      owner: owner,
      repo_name: repo_name,
      commit_sha: Map.get(latest_commit, "id", ""),
      commit_message: Map.get(latest_commit, "message", ""),
      commit_author: Map.get(author, "name", ""),
      author_email: Map.get(author, "email", ""),
      pr_name: "",
      pr_number: 0
    }
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

  def extract_actor_id(payload = %{"object_kind" => "merge_request"}),
    do: get_in(payload, ["user", "id"]) |> to_string()

  def extract_actor_id(payload), do: Map.get(payload, "user_id") |> to_string()
end
