defmodule RepositoryHub.GitCliClientTest do
  @moduledoc """
  Exercises the real `git` binary against a throwaway local repository served over
  the `file://` transport, which goes through the same upload-pack path as SSH.
  """
  use ExUnit.Case, async: true

  alias RepositoryHub.GitCliClient

  # The key is never used by the file:// transport; it only has to be written to disk.
  @opts [private_key: "-----BEGIN OPENSSH PRIVATE KEY-----\nnot-a-real-key\n-----END OPENSSH PRIVATE KEY-----"]

  setup do
    dir = Path.join(System.tmp_dir!(), "git_cli_client_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)

    git!(dir, ["init", "--quiet", "--initial-branch", "main"])
    git!(dir, ["config", "user.name", "Ada Lovelace"])
    git!(dir, ["config", "user.email", "ada@example.com"])
    git!(dir, ["config", "uploadpack.allowAnySHA1InWant", "true"])

    File.write!(Path.join(dir, "README.md"), "hello\n")
    git!(dir, ["add", "README.md"])
    git!(dir, ["commit", "--quiet", "--message", "Initial commit\n\nWith a body."])
    first_sha = git!(dir, ["rev-parse", "HEAD"])

    git!(dir, ["tag", "--annotate", "v1.0.0", "--message", "First release"])

    File.write!(Path.join(dir, "README.md"), "hello again\n")
    git!(dir, ["commit", "--quiet", "--all", "--message", "Second commit"])
    second_sha = git!(dir, ["rev-parse", "HEAD"])

    git!(dir, ["branch", "feature/login"])

    %{url: "file://#{dir}", first_sha: first_sha, second_sha: second_sha}
  end

  describe "get_reference/2" do
    test "resolves a fully qualified branch", %{url: url, second_sha: sha} do
      assert {:ok, %{type: "branch", reference: "refs/heads/main", sha: ^sha}} =
               GitCliClient.get_reference(%{url: url, reference: "refs/heads/main"}, @opts)
    end

    test "resolves a bare branch name", %{url: url, second_sha: sha} do
      assert {:ok, %{type: "branch", reference: "refs/heads/feature/login", sha: ^sha}} =
               GitCliClient.get_reference(%{url: url, reference: "feature/login"}, @opts)
    end

    test "resolves an annotated tag to the commit it points at", %{url: url, first_sha: sha} do
      assert {:ok, %{type: "tag", reference: "refs/tags/v1.0.0", sha: ^sha}} =
               GitCliClient.get_reference(%{url: url, reference: "refs/tags/v1.0.0"}, @opts)

      assert {:ok, %{type: "tag", sha: ^sha}} = GitCliClient.get_reference(%{url: url, reference: "v1.0.0"}, @opts)
    end

    test "reports an unknown reference as not found", %{url: url} do
      not_found = GRPC.Status.not_found()

      assert {:error, %{status: ^not_found, message: message}} =
               GitCliClient.get_reference(%{url: url, reference: "refs/heads/nope"}, @opts)

      assert message =~ "refs/heads/nope"
    end

    test "reports an unreachable repository as a failed precondition" do
      failed_precondition = GRPC.Status.failed_precondition()

      assert {:error, %{status: ^failed_precondition, message: message}} =
               GitCliClient.get_reference(
                 %{url: "file://#{System.tmp_dir!()}/definitely/not/a/repo.git", reference: "refs/heads/main"},
                 @opts
               )

      assert message =~ "Unable to list references"
    end
  end

  describe "get_commit/2" do
    test "reads the commit at a reference", %{url: url, second_sha: sha} do
      assert {:ok, commit} = GitCliClient.get_commit(%{url: url, revision: "refs/heads/main"}, @opts)

      assert commit.sha == sha
      assert commit.message == "Second commit"
      assert commit.author_name == "Ada Lovelace"
      assert commit.author_email == "ada@example.com"
    end

    test "reads a commit by sha and keeps the message body", %{url: url, first_sha: sha} do
      assert {:ok, commit} = GitCliClient.get_commit(%{url: url, revision: sha}, @opts)

      assert commit.sha == sha
      assert commit.message == "Initial commit\n\nWith a body."
    end

    test "reports an unknown revision as not found", %{url: url} do
      not_found = GRPC.Status.not_found()

      assert {:error, %{status: ^not_found, message: message}} =
               GitCliClient.get_commit(%{url: url, revision: String.duplicate("a", 40)}, @opts)

      assert message =~ "Unable to fetch revision"
    end
  end

  defp git!(dir, args) do
    {output, 0} = System.cmd("git", ["-C", dir | args], stderr_to_stdout: true)
    String.trim(output)
  end
end
