defmodule Projecthub.Models.DeployKeyTest do
  use Projecthub.DataCase
  import Mock

  alias Projecthub.Models.DeployKey

  @repo %{owner: "renderedtext", name: "projecthub"}
  @unsafe_repo %{owner: "renderedtext", name: "projecthub\r\nX-Injected: yes"}

  defp deploy_key(attrs \\ %{}) do
    Map.merge(
      %DeployKey{
        id: Ecto.UUID.generate(),
        remote_id: 42,
        public_key: "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ==",
        deployed: false
      },
      attrs
    )
  end

  describe ".get_from_github" do
    test "rejects an unsafe repo owner/name before making any GitHub call" do
      with_mock Tentacat.Repositories.DeployKeys, [],
        find: fn _client, _owner, _name, _id -> flunk("Tentacat should not be called") end do
        assert DeployKey.get_from_github(deploy_key(), @unsafe_repo, "token") ==
                 {:error, :invalid_github_path_segment}
      end
    end

    test "still reaches GitHub with the expected owner/name for a legitimate repo" do
      with_mock Tentacat.Repositories.DeployKeys, [],
        find: fn _client, owner, name, remote_id ->
          assert owner == "renderedtext"
          assert name == "projecthub"
          assert remote_id == 42
          {200, %{"title" => "semaphore-renderedtext-projecthub"}, %{}}
        end do
        assert DeployKey.get_from_github(deploy_key(), @repo, "token") ==
                 {:ok, %{title: "semaphore-renderedtext-projecthub"}}
      end
    end
  end

  describe ".remove_from_github" do
    test "rejects an unsafe repo owner/name before making any GitHub call" do
      with_mock Tentacat.Repositories.DeployKeys, [],
        remove: fn _client, _owner, _name, _id -> flunk("Tentacat should not be called") end do
        assert DeployKey.remove_from_github(deploy_key(), @unsafe_repo, "token") ==
                 {:error, :invalid_github_path_segment}
      end
    end

    test "still reaches GitHub with the expected owner/name for a legitimate repo" do
      with_mock Tentacat.Repositories.DeployKeys, [],
        remove: fn _client, owner, name, remote_id ->
          assert owner == "renderedtext"
          assert name == "projecthub"
          assert remote_id == 42
          {204, nil, nil}
        end do
        DeployKey.remove_from_github(deploy_key(), @repo, "token")
        assert_called(Tentacat.Repositories.DeployKeys.remove(:_, "renderedtext", "projecthub", 42))
      end
    end
  end

  describe ".deploy_to_github" do
    test "rejects an unsafe repo owner/name before making any GitHub call" do
      with_mock Tentacat.Repositories.DeployKeys, [],
        create: fn _client, _owner, _name, _body -> flunk("Tentacat should not be called") end do
        assert DeployKey.deploy_to_github(
                 deploy_key(),
                 %{id: "proj-1", name: "proj"},
                 @unsafe_repo,
                 "token"
               ) == {:error, :invalid_github_path_segment}
      end
    end

    test "still reaches GitHub with the expected owner/name for a legitimate repo" do
      persisted_deploy_key = Projecthub.Repo.insert!(deploy_key())

      with_mock Tentacat.Repositories.DeployKeys, [],
        create: fn _client, owner, name, body ->
          assert owner == "renderedtext"
          assert name == "projecthub"
          assert body.read_only == true
          {201, %{"id" => 99}, %{}}
        end do
        assert {:ok, updated_deploy_key} =
                 DeployKey.deploy_to_github(
                   persisted_deploy_key,
                   %{id: "proj-1", name: "proj"},
                   @repo,
                   "token"
                 )

        assert updated_deploy_key.remote_id == 99
        assert updated_deploy_key.deployed == true
      end
    end
  end
end
