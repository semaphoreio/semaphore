defmodule Projecthub.RepoUrlTest do
  use ExUnit.Case, async: true

  alias Projecthub.RepoUrl

  describe ".validate" do
    test "accepts GitHub and both Bitbucket SSH hosts" do
      for url <- [
            "git@github.com:foo/bar.git",
            "git@bitbucket.org:foo/bar.git",
            "git@ssh.bitbucket.org:foo/bar.git"
          ] do
        assert {:ok, %RepoUrl{owner: "foo", repo: "bar"}} = RepoUrl.validate(url)
      end
    end

    test "keeps the host it was given" do
      assert {:ok, %RepoUrl{ssh_git_url: "git@ssh.bitbucket.org:foo/bar.git"}} =
               RepoUrl.validate("git@ssh.bitbucket.org:foo/bar.git")
    end

    test "rejects other hosts" do
      assert {:error, ["Repository host must be GitHub.com or Bitbucket.org"]} =
               RepoUrl.validate("git@notbitbucket.org:foo/bar.git")
    end
  end
end
