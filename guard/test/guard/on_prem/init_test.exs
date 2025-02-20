defmodule Guard.OnPrem.Init.Test do
  use Guard.RepoCase, async: true

  import Mock
  import Ecto.Query

  alias Guard.OnPrem.Init

  setup do
    System.delete_env("ORGANIZATION_SEED_ORG_NAME")
    System.delete_env("ORGANIZATION_SEED_ORG_USERNAME")
    System.delete_env("ORGANIZATION_SEED_OWNER_GITHUB_USERNAME")
    System.delete_env("ORGANIZATION_SEED_OWNER_EMAIL")
  end

  describe "init/1" do
    test "Exit with 1 when env vars are not present" do
      assert catch_exit(Init.init()) == {:shutdown, 1}
    end

    test "Skip setup if org already exists" do
      Support.Factories.Organization.insert!()

      assert catch_exit(Init.init()) == {:shutdown, 0}
    end

    test "Throw error when github user can't be retreated" do
      gh_username = "test_username"
      insert_env_vars(owner_gh_username: gh_username)

      with_mock HTTPoison, get: fn _ -> {:ok, %{status_code: 404}} end do
        assert catch_exit(Init.init()) == {:shutdown, 1}
        assert_called_exactly(HTTPoison.get("https://api.github.com/users/#{gh_username}"), 1)
      end
    end

    test "Throw error when github can't be reached" do
      insert_env_vars()

      with_mock HTTPoison, get: fn _ -> {:error, %{}} end do
        assert catch_exit(Init.init()) == {:shutdown, 1}
        assert_called_exactly(HTTPoison.get(:_), 1)
      end
    end

    test "Check if everything is created properly when name is present" do
      with_mock Guard.Events.UserCreated, publish: fn _, _ -> :ok end do
        insert_env_vars()
        github_uid = Ecto.UUID.generate()
        github_name = "John Petrucci"

        with_mock HTTPoison,
          get: fn _ ->
            {:ok,
             %{
               body: "{\"id\":\"#{github_uid}\",\"name\":\"#{github_name}\",\"login\":null}",
               status_code: 200
             }}
          end do
          Init.init()
        end

        assert_org_created()
        assert_user_created()
        assert_org_member_added()
        assert_oauth_connection_created()
        assert_repo_host_account_created()
      end
    end

    test "Check if everything is created properly when name is nil" do
      with_mock Guard.Events.UserCreated, publish: fn _, _ -> :ok end do
        insert_env_vars()
        github_uid = Ecto.UUID.generate()
        login_name = System.get_env("ORGANIZATION_SEED_OWNER_GITHUB_USERNAME")

        with_mock HTTPoison,
          get: fn _ ->
            {:ok,
             %{
               body: "{\"id\":\"#{github_uid}\",\"name\":null,\"login\":\"#{login_name}\"}",
               status_code: 200
             }}
          end do
          Init.init()
        end

        assert_org_created()
        assert_user_created()
        assert_org_member_added()
        assert_oauth_connection_created()
        assert_repo_host_account_created()
      end
    end
  end

  ###
  ### Helper functions
  ###

  defp insert_env_vars(options \\ []) do
    defaults = [
      org_name: "Org_name",
      org_username: "Org_username",
      owner_gh_username: "gh_username",
      owner_email: "owner@email.com"
    ]

    options = Keyword.merge(defaults, options)
    System.put_env("ORGANIZATION_SEED_ORG_NAME", options[:org_name])
    System.put_env("ORGANIZATION_SEED_ORG_USERNAME", options[:org_username])
    System.put_env("ORGANIZATION_SEED_OWNER_GITHUB_USERNAME", options[:owner_gh_username])
    System.put_env("ORGANIZATION_SEED_OWNER_EMAIL", options[:owner_email])
  end

  defp assert_org_created do
    org_name = System.get_env("ORGANIZATION_SEED_ORG_USERNAME")

    assert Guard.FrontRepo.Organization
           |> where(username: ^org_name)
           |> Guard.FrontRepo.exists?()
  end

  defp assert_user_created do
    import Ecto.Query

    email = System.get_env("ORGANIZATION_SEED_OWNER_EMAIL")

    user = Guard.FrontRepo.one(from(u in Guard.FrontRepo.User, where: u.email == ^email))

    assert user != nil
    assert user.authentication_token == nil
    assert user.salt != nil
    assert user.remember_created_at != nil
  end

  defp assert_oauth_connection_created do
    assert Guard.FrontRepo.OauthConnection |> Guard.FrontRepo.exists?()
  end

  def assert_org_member_added do
    assert Guard.FrontRepo.Member |> Guard.FrontRepo.exists?()
  end

  defp assert_repo_host_account_created do
    import Ecto.Query

    login = System.get_env("ORGANIZATION_SEED_OWNER_GITHUB_USERNAME")

    rha =
      Guard.FrontRepo.one(from(u in Guard.FrontRepo.RepoHostAccount, where: u.login == ^login))

    assert rha != nil
    assert rha.created_at != nil
    assert rha.updated_at != nil
  end
end
