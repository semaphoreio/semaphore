defmodule RepositoryHub.Model.GitRepositoryTest do
  use ExUnit.Case
  alias RepositoryHub.Model.GitRepository
  doctest GitRepository

  describe "GitRepository validations" do
    test "SSH URL format => no errors" do
      url = "git@github.com:marvinwills/base-app.git"

      {:ok, url_parts} = GitRepository.new(url)

      assert url_parts.protocol == ""
      assert url_parts.host == "github.com"
      assert url_parts.owner == "marvinwills"
      assert url_parts.repo == "base-app"
    end

    test "SSH URL from root => no errors" do
      url = "git@github.com:/marvinwills/base-app.git"

      {:ok, url_parts} = GitRepository.new(url)

      assert url_parts.protocol == ""
      assert url_parts.host == "github.com"
      assert url_parts.owner == "marvinwills"
      assert url_parts.repo == "base-app"
    end

    test "SSH URL without .git sufix => no errors" do
      url = "git@github.com:/marvinwills/base-app"

      {:ok, url_parts} = GitRepository.new(url)

      assert url_parts.protocol == ""
      assert url_parts.host == "github.com"
      assert url_parts.owner == "marvinwills"
      assert url_parts.repo == "base-app"
    end

    test "SSH URL with protocol => no errors" do
      url = "ssh://git@github.com:/marvinwills/base-app.git"

      {:ok, url_parts} = GitRepository.new(url)

      assert url_parts.protocol == "ssh://"
      assert url_parts.host == "github.com"
      assert url_parts.owner == "marvinwills"
      assert url_parts.repo == "base-app"
    end

    test "HTTP URL => no errors" do
      url = "https://github.com/shiroyasha/base-app"

      {:ok, url_parts} = GitRepository.new(url)

      assert url_parts.protocol == "https://"
      assert url_parts.host == "github.com"
      assert url_parts.owner == "shiroyasha"
      assert url_parts.repo == "base-app"
    end

    test "HTTP URL with .git sufix => no errors" do
      url = "https://github.com/shiroyasha/base-app.git"

      {:ok, url_parts} = GitRepository.new(url)

      assert url_parts.protocol == "https://"
      assert url_parts.host == "github.com"
      assert url_parts.owner == "shiroyasha"
      assert url_parts.repo == "base-app"
    end

    test "valid URL with dots in name => no errors" do
      url = "git@github.com:marvinwills/base.app.com.git"

      {:ok, url_parts} = GitRepository.new(url)

      assert url_parts.protocol == ""
      assert url_parts.host == "github.com"
      assert url_parts.owner == "marvinwills"
      assert url_parts.repo == "base.app.com"
    end

    test "broken url => ❌" do
      url = "github.com shiroyasha$$$base-app.git"

      {:error, error} = GitRepository.new(url)
      assert error == "Unrecognized Git remote format 'github.com shiroyasha$$$base-app.git'"
    end

    test "Bitbucket endpoint => ✅" do
      url = "git@bitbucket.org:marvinwills/base-app.git"

      {:ok, url_parts} = GitRepository.new(url)
      assert url_parts.protocol == ""
      assert url_parts.host == "bitbucket.org"
      assert url_parts.owner == "marvinwills"
      assert url_parts.repo == "base-app"
    end

    test "Github endpoint => ✅" do
      url = "git@github.com:marvinwills/base-app.git"

      {:ok, url_parts} = GitRepository.new(url)
      assert url_parts.protocol == ""
      assert url_parts.host == "github.com"
      assert url_parts.owner == "marvinwills"
      assert url_parts.repo == "base-app"
    end

    test "GitLab subgroup SSH URL => ✅" do
      url = "git@gitlab.com:testorg/testgroup/testrepo.git"

      {:ok, url_parts} = GitRepository.from_gitlab(url)
      assert url_parts.protocol == ""
      assert url_parts.host == "gitlab.com"
      assert url_parts.owner == "testorg/testgroup"
      assert url_parts.repo == "testrepo"
      assert url_parts.ssh_git_url == "git@gitlab.com:testorg/testgroup/testrepo.git"
    end

    test "GitLab subgroup HTTPS URL => ✅" do
      url = "https://gitlab.com/testorg/testgroup/testrepo.git"

      {:ok, url_parts} = GitRepository.from_gitlab(url)
      assert url_parts.protocol == "https://"
      assert url_parts.host == "gitlab.com"
      assert url_parts.owner == "testorg/testgroup"
      assert url_parts.repo == "testrepo"
      assert url_parts.ssh_git_url == "git@gitlab.com:testorg/testgroup/testrepo.git"
    end
  end

  describe ".equal?" do
    test "when the new url is valid and equal => return truthy tuple" do
      {:ok, git_repository} =
        "git@github.com:marvinwills/base-app.git"
        |> GitRepository.new()

      new_url = "https://github.com/marvinwills/base-app"

      {:ok, true} = GitRepository.equal?(git_repository, new_url)
    end

    test "when the new url is valid and different => returns falsey tuple" do
      {:ok, git_repository} =
        "git@github.com:marvinwills/base-app.git"
        |> GitRepository.new()

      new_url = "git@github.com:shiroyasha/base-app.git"

      {:ok, false} = GitRepository.equal?(git_repository, new_url)
    end

    test "when the new url is invalid => ❌" do
      {:ok, git_repository} =
        "git@github.com:marvinwills/base-app.git"
        |> GitRepository.new()

      new_url = "git@gitea.com:marvinwills/base-app.git"

      assert {:ok, false} == GitRepository.equal?(git_repository, new_url)
    end
  end
end
