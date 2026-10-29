defmodule RepositoryHub.GitCliClient do
  @moduledoc """
  Talks to a plain git server with the `git` command line, over SSH, authenticated
  with the repository deploy key.

  Generic Git repositories have no provider API (GitHub, GitLab, Bitbucket) to ask
  about branches, tags and commits. The only thing the server exposes is the git
  protocol itself, and the only credential Semaphore holds is the deploy key it
  generated for the project. This module uses both:

    * `get_reference/2` runs `git ls-remote` to resolve a branch or tag to a commit sha
    * `get_commit/2` fetches a single commit (depth 1, no trees nor blobs when the
      server supports partial clone) into a throwaway bare repository and reads its
      message and author

  The deploy key is written to a private temporary directory for the duration of the
  command and removed right after. The host key is trusted on first use and remembered
  in a `known_hosts` file under the system temporary directory, so the plane behaves
  like a fresh `ssh` client would with `StrictHostKeyChecking=accept-new`.
  """

  alias RepositoryHub.Toolkit
  import Toolkit

  @type options() :: [private_key: String.t(), timeout: pos_integer()]

  @type get_reference_request :: %{url: String.t(), reference: String.t()}
  @type get_reference_response :: %{type: String.t(), sha: String.t(), reference: String.t()}

  @type get_commit_request :: %{url: String.t(), revision: String.t()}
  @type get_commit_response :: %{
          sha: String.t(),
          message: String.t(),
          author_name: String.t(),
          author_email: String.t()
        }

  @default_timeout_seconds 30
  @log_format "%H%x1f%an%x1f%ae%x1f%B"

  @doc """
  Resolves a git reference to a commit sha with `git ls-remote`.

  `reference` can be fully qualified (`refs/heads/main`, `refs/tags/v1.0.0`) or a bare
  name, in which case branches win over tags. Annotated tags resolve to the commit they
  point at, not to the tag object.
  """
  @spec get_reference(get_reference_request(), options()) :: Toolkit.tupled_result(get_reference_response())
  def get_reference(%{url: url, reference: reference}, opts) do
    with_deploy_key(opts, fn env ->
      # The peeled entry of an annotated tag is only listed when asked for explicitly.
      case git(["ls-remote", url, reference, reference <> "^{}"], env, opts) do
        {:ok, output} ->
          output
          |> parse_ls_remote()
          |> pick_reference(reference)
          |> case do
            nil -> fail_with(:not_found, "Reference '#{reference}' not found.")
            found -> wrap(found)
          end

        {:error, message} ->
          fail_with(:precondition, "Unable to list references of #{url}: #{message}")
      end
    end)
  end

  @doc """
  Fetches one commit and returns its sha, message and author.

  `revision` is whatever `git fetch` accepts: a fully qualified reference or a commit
  sha. Fetching by sha needs `uploadpack.allowAnySHA1InWant` (or a reachable sha with
  `uploadpack.allowReachableSHA1InWant`) on the server, which Forgejo, Gitea, GitHub
  and GitLab all allow.
  """
  @spec get_commit(get_commit_request(), options()) :: Toolkit.tupled_result(get_commit_response())
  def get_commit(%{url: url, revision: revision}, opts) do
    with_deploy_key(opts, fn env ->
      with_temporary_directory(fn repo_dir ->
        with {:ok, _} <- git(["init", "--quiet", "--bare", repo_dir], env, opts),
             {:ok, _} <- fetch(repo_dir, url, revision, env, opts),
             {:ok, output} <- git(["-C", repo_dir, "log", "-1", "--format=#{@log_format}", "FETCH_HEAD"], env, opts) do
          parse_log(output)
        else
          {:error, message} ->
            fail_with(:not_found, "Unable to fetch revision '#{revision}' from #{url}: #{message}")
        end
      end)
    end)
  end

  # A blob-less and tree-less fetch is enough to read the commit itself. Servers that
  # do not support partial clone answer with an error instead of ignoring the filter,
  # so retry the plain way before giving up.
  defp fetch(repo_dir, url, revision, env, opts) do
    base = ["-C", repo_dir, "fetch", "--quiet", "--no-tags", "--depth", "1"]

    case git(base ++ ["--filter=tree:0", url, revision], env, opts) do
      {:ok, _} = ok -> ok
      {:error, _} -> git(base ++ [url, revision], env, opts)
    end
  end

  defp parse_ls_remote(output) do
    output
    |> String.split("\n", trim: true)
    |> Enum.flat_map(fn line ->
      case String.split(line, "\t", parts: 2) do
        [sha, name] -> [{String.trim(name), String.trim(sha)}]
        _ -> []
      end
    end)
    |> Map.new()
  end

  defp pick_reference(refs, reference) do
    candidates =
      case reference do
        "refs/" <> _ -> [reference]
        name -> ["refs/heads/#{name}", "refs/tags/#{name}"]
      end

    Enum.find_value(candidates, fn candidate ->
      case Map.fetch(refs, candidate) do
        {:ok, sha} ->
          %{
            type: reference_type(candidate),
            reference: candidate,
            # An annotated tag advertises a peeled entry pointing at the commit.
            sha: Map.get(refs, candidate <> "^{}", sha)
          }

        :error ->
          nil
      end
    end)
  end

  defp reference_type("refs/heads/" <> _), do: "branch"
  defp reference_type("refs/tags/" <> _), do: "tag"
  defp reference_type(_), do: "commit"

  defp parse_log(output) do
    case String.split(output, "\x1f", parts: 4) do
      [sha, author_name, author_email, message] ->
        %{
          sha: String.trim(sha),
          author_name: String.trim(author_name),
          author_email: String.trim(author_email),
          message: String.trim_trailing(message)
        }
        |> wrap()

      _ ->
        fail_with(:not_found, "Unable to read the fetched commit.")
    end
  end

  defp git(args, env, opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout_seconds)
    {command, args} = with_timeout(timeout, "git", args)

    case System.cmd(command, args, env: env, stderr_to_stdout: true) do
      {output, 0} ->
        wrap(output)

      {_output, 124} ->
        error("timed out after #{timeout}s")

      {output, _status} ->
        error(first_line(output))
    end
  rescue
    e in ErlangError ->
      error("git command failed: #{inspect(e.original)}")
  end

  # Busybox and coreutils both ship `timeout`; without it the command simply runs unbounded.
  defp with_timeout(timeout, command, args) do
    case System.find_executable("timeout") do
      nil -> {command, args}
      path -> {path, [to_string(timeout), command | args]}
    end
  end

  defp first_line(output) do
    output
    |> String.split("\n", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> List.first("unknown error")
  end

  defp with_deploy_key(opts, fun) do
    private_key = Keyword.fetch!(opts, :private_key)

    with_temporary_directory(fn dir ->
      key_path = Path.join(dir, "deploy_key")
      File.write!(key_path, with_trailing_newline(private_key))
      File.chmod!(key_path, 0o600)

      fun.(git_env(key_path))
    end)
  end

  defp with_temporary_directory(fun) do
    dir = Path.join(System.tmp_dir!(), "repository_hub_git_#{random_integer()}_#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    File.chmod!(dir, 0o700)

    try do
      fun.(dir)
    after
      File.rm_rf(dir)
    end
  end

  defp git_env(key_path) do
    ssh_command =
      Enum.join(
        [
          "ssh",
          "-i #{key_path}",
          "-o IdentitiesOnly=yes",
          "-o BatchMode=yes",
          "-o ConnectTimeout=10",
          "-o StrictHostKeyChecking=accept-new",
          "-o UserKnownHostsFile=#{known_hosts_path()}"
        ],
        " "
      )

    [
      {"GIT_SSH_COMMAND", ssh_command},
      {"GIT_TERMINAL_PROMPT", "0"},
      {"GIT_LFS_SKIP_SMUDGE", "1"}
    ]
  end

  defp known_hosts_path do
    path = Path.join(System.tmp_dir!(), "repository_hub_known_hosts")
    File.touch(path)
    path
  end

  defp with_trailing_newline(key) do
    if String.ends_with?(key, "\n"), do: key, else: key <> "\n"
  end
end
