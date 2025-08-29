defmodule HooksProcessor.Hooks.Payload.Bitbucket do
  @moduledoc """
  Encapsulates operations on bitbucket hooks payload.
  """

  @doc """
  Extracts hook type from hook payload.
  """
  def hook_type(payload) do
    cond do
      Map.has_key?(payload, "push") ->
        change = payload |> get_in(["push", "changes"]) |> Enum.at(0)

        (Map.get(change, "new") || Map.get(change, "old")) |> Map.get("type")

      Map.has_key?(payload, "pullrequest") ->
        payload |> get_in(["pullrequest", "type"])
    end
  end

  @doc """
  Used for concluding whether branch or tag was created, updated or deleted via given push
  """
  def branch_action(payload) do
    change = payload |> get_in(["push", "changes"]) |> Enum.at(0)

    cond do
      Map.get(change, "closed") -> "deleted"
      Map.get(change, "created") -> "new"
      true -> "push"
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

  @doc """
  Extracts from payload all data necessary for branch creation and workkflow scheduling
  """
  def extract_data(payload, hook_type, action_type)

  def extract_data(payload, "tag", "deleted") do
    change = payload |> get_in(["push", "changes"]) |> Enum.at(0) |> Map.get("old")
    extract_tag_data_(payload, change)
  end

  def extract_data(payload, "tag", _action_type) do
    change = payload |> get_in(["push", "changes"]) |> Enum.at(0) |> Map.get("new")
    extract_tag_data_(payload, change)
  end

  def extract_data(payload, "branch", "deleted") do
    change = payload |> get_in(["push", "changes"]) |> Enum.at(0) |> Map.get("old")

    extract_branch_data_(payload, change)
  end

  def extract_data(payload, "branch", _action_type) do
    change = payload |> get_in(["push", "changes"]) |> Enum.at(0) |> Map.get("new")

    extract_branch_data_(payload, change)
  end

  defp extract_branch_data_(payload, change) do
    branch_name = Map.get(change, "name")
    target = Map.get(change, "target")
    repo_name = payload |> Map.get("repository") |> Map.get("name")
    owner = payload |> get_in(["repository", "workspace", "slug"])

    author =
      get_in(target, ["author", "user", "nickname"]) ||
        get_in(payload, ["actor", "nickname"])

    %{
      branch_name: branch_name,
      git_ref: "refs/heads/" <> branch_name,
      display_name: branch_name,
      owner: owner,
      repo_name: repo_name,
      commit_sha: Map.get(target, "hash"),
      commit_message: Map.get(target, "message"),
      commit_author: author,
      pr_name: "",
      pr_number: 0
    }
  end

  defp extract_tag_data_(payload, change) do
    tag_name = Map.get(change, "name")
    target = Map.get(change, "target")
    repo_name = payload |> Map.get("repository") |> Map.get("name")
    owner = payload |> get_in(["repository", "workspace", "slug"])

    author =
      get_in(target, ["author", "user", "nickname"]) ||
        get_in(payload, ["actor", "nickname"])

    %{
      branch_name: "refs/tags/" <> tag_name,
      git_ref: "refs/tags/" <> tag_name,
      display_name: tag_name,
      owner: owner,
      repo_name: repo_name,
      commit_sha: Map.get(target, "hash"),
      commit_message: Map.get(target, "message"),
      commit_author: author,
      pr_name: "",
      pr_number: 0
    }
  end

  @doc """
  Extracts from payload provider's id of requester
  """
  def extract_actor_id(payload) do
    payload |> get_in(["actor", "uuid"])
  end
end
