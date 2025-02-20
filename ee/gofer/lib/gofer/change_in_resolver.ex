defmodule Gofer.ChangeInResolver do
  @moduledoc """
  Module is used for resolving when conditions which include 'change_id' function
  that evaluates whether given file was changed in given range of commits.
  """

  alias Gofer.RepoHubClient

  @commit_sha_env_var "$SEMAPHORE_GIT_SHA"
  @cm_range_env_var "$SEMAPHORE_GIT_COMMIT_RANGE"
  @merge_base_env_var "$SEMAPHORE_MERGE_BASE"

  defp default_args() do
    %{
      default_branch: "master",
      default_range: @cm_range_env_var,
      branch_range: "#{@merge_base_env_var}...#{@commit_sha_env_var}",
      # other option is 'track'
      pipeline_file: "ignore",
      on_tags: true
    }
  end

  def change_in(path, params) when is_binary(path) and path != "",
    do: change_in([path], default_args(), params)

  def change_in(paths, params) when is_list(paths) and paths != [],
    do: change_in(paths, default_args(), params)

  def change_in(paths, _params),
    do: invalid_param_error(:first, paths)

  def change_in(path, args = %{}, params) when is_binary(path) and path != "",
    do: change_in([path], args, params)

  def change_in(paths, args = %{}, params) when is_list(paths) and paths != [] do
    with {:is_tag, false, _} <- check_if_tag(args, params),
         # extract important params
         project_id when is_binary(project_id) and project_id != "" <-
           Map.get(params, "project_id", missing_param_error("project_id")),
         current_sha when is_binary(current_sha) and current_sha != "" <-
           Map.get(params, "commit_sha", missing_param_error("commit_sha")),
         commit_range when is_binary(commit_range) and commit_range != "" <-
           Map.get(params, "commit_range", missing_param_error("commit_range")),
         working_dir when is_binary(working_dir) and working_dir != "" <-
           Map.get(params, "working_dir", missing_param_error("working_dir")),
         yml_file_name when is_binary(yml_file_name) and yml_file_name != "" <-
           Map.get(params, "yml_file_name", missing_param_error("yml_file_name")),
         # prepare paths and changes
         args <- default_args() |> Map.merge(args),
         {:ok, repo_id} <- RepoHubClient.get_repo_id(project_id),
         {:ok, diff_params} <- parse_range(args, params, current_sha, commit_range),
         diff_params <- Map.put(diff_params, :repository_id, repo_id),
         {:ok, changed_paths} <- RepoHubClient.get_changes(diff_params),
         {:ok, paths} <- add_yml_file?(args, paths, yml_file_name) do
      paths_in_changed_ones?(paths, working_dir, changed_paths)
    else
      {:is_tag, true, on_tags} -> {:ok, on_tags}
      e = {:error, _} -> e
      error -> {:error, "#{inspect(error)}"}
    end
  end

  def change_in(paths, %{}, _params), do: invalid_param_error(:first, paths)
  def change_in(_paths, args, _params), do: invalid_param_error(:second, args)

  defp missing_param_error(param), do: {:error, "Missing parameter '#{param}'."}

  defp invalid_param_error(:first, param) do
    {:error,
     "First parameter is invalid, expected string or list of strings," <>
       " received: #{inspect(param)}"}
  end

  defp invalid_param_error(:second, param) do
    {:error, "Second parameter is invalid, expected a map, received: #{inspect(param)}"}
  end

  defp check_if_tag(args, %{"tag" => tag}) when is_binary(tag) and tag != "" do
    {:is_tag, true, args.on_tags}
  end

  defp check_if_tag(_args, _params), do: {:is_tag, false, false}

  defp parse_range(args, params, current_sha, commit_range) do
    with branch when is_binary(branch) <-
           Map.get(params, "branch", missing_param_error("branch")),
         pr_base when is_binary(pr_base) <-
           Map.get(params, "pr_base", missing_param_error("pr_base")),
         {:ok, merge_base} <- decide_base(args, branch, pr_base),
         {:ok, diff_range} <- decide_diff_range(args, branch, pr_base) do
      parse_range_(diff_range, merge_base, current_sha, commit_range)
    end
  end

  defp decide_base(%{default_branch: default}, branch, "") when branch != "",
    do: {:ok, default}

  defp decide_base(_args, "", pr_base) when pr_base != "", do: {:ok, pr_base}

  defp decide_diff_range(args = %{default_branch: default}, branch, "")
       when branch == default,
       do: {:ok, args.default_range}

  defp decide_diff_range(args, _branch, _pr_base), do: {:ok, args.branch_range}

  defp parse_range_(diff_range, merge_base, current_sha, commit_range) do
    diff_range
    |> three_dots_split?()
    |> two_dots_split?()
    |> replace_env_vars(merge_base, current_sha, commit_range)
    |> to_repo_hub_req_format()
  end

  defp three_dots_split?(diff_range) do
    {:ok, diff_range |> String.split("..."), :HEAD_TO_MERGE_BASE}
  end

  defp two_dots_split?(resp = {:ok, list, _}) when length(list) == 2, do: resp

  defp two_dots_split?({:ok, list, _comp_type}) when length(list) == 1 do
    {:ok, list |> Enum.at(0) |> String.split(".."), :HEAD_TO_HEAD}
  end

  defp two_dots_split?({:ok, list, _}),
    do: {:error, "Invalid commit range value: '#{list |> Enum.join("...")}'."}

  defp replace_env_vars({:ok, [@cm_range_env_var], _ct}, _mb, _c_sha, commit_range) do
    [base, head] = commit_range |> String.split("...")
    {:ok, %{commit_sha: base}, %{commit_sha: head}, :HEAD_TO_MERGE_BASE}
  end

  defp replace_env_vars(
         {:ok, [@merge_base_env_var, @commit_sha_env_var], comp_type},
         merge_base,
         current_sha,
         _commit_range
       ),
       do: {:ok, %{reference: ref(merge_base)}, %{commit_sha: current_sha}, comp_type}

  defp replace_env_vars({:ok, [@merge_base_env_var, head], comp_type}, merge_base, _c_s, _c_r),
    do: {:ok, %{reference: ref(merge_base)}, %{reference: ref(head)}, comp_type}

  defp replace_env_vars({:ok, [base, @commit_sha_env_var], comp_type}, _mb, current_sha, _c_r),
    do: {:ok, %{reference: ref(base)}, %{commit_sha: current_sha}, comp_type}

  defp replace_env_vars({:ok, [base, head], comp_type}, _mb, _c_s, _c_r),
    do: {:ok, %{reference: ref(base)}, %{reference: ref(head)}, comp_type}

  defp replace_env_vars(error, _mb, _current_sha, _c_r), do: error

  defp ref(name), do: "refs/heads/" <> name

  defp to_repo_hub_req_format({:ok, base, head, comp_type}) do
    {:ok, %{head_rev: head, base_rev: base, comparison_type: comp_type}}
  end

  defp to_repo_hub_req_format(error), do: error

  defp add_yml_file?(%{pipeline_file: "ignore"}, paths, _y_f_n),
    do: {:ok, paths}

  defp add_yml_file?(%{pipeline_file: "track"}, paths, yml_file) do
    {:ok, paths ++ [yml_file]}
  end

  defp add_yml_file?(%{pipeline_file: val}, _paths, _y_f_n) do
    {:error, "Invalid value of 'pipeline_file' parameter: '#{inspect(val)}'."}
  end

  defp paths_in_changed_ones?(paths, working_dir, changed_paths) do
    paths
    |> Enum.reduce_while({:ok, false}, fn path, _result ->
      working_dir
      |> full_path(path)
      |> path_in_changed_ones?(changed_paths)
      |> case do
        true -> {:halt, {:ok, true}}
        _ -> {:cont, {:ok, false}}
      end
    end)
  end

  # If path starts with "/" it is absolute path => disregard working dir
  defp full_path(_working_dir, _path = "/" <> rest), do: rest

  defp full_path(working_dir, path),
    do: working_dir |> Path.join(path) |> normalize_path()

  defp normalize_path(path),
    do: path |> Path.expand() |> Path.relative_to_cwd()

  defp path_in_changed_ones?(path, changed_paths) do
    changed_paths
    |> Enum.any?(fn changed_path ->
      String.starts_with?(changed_path, path)
    end)
  end
end
