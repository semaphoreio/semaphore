defmodule Guard.InviteesTest do
  use Guard.RepoCase, async: true

  import Mock
  import ExUnit.CaptureLog

  alias Guard.Invitees

  @inviter_id Ecto.UUID.generate()

  setup do
    Guard.FrontRepo.delete_all(Guard.FrontRepo.RepoHostAccount)

    Support.Members.insert_repo_host_account(
      login: "bar",
      github_uid: "222",
      user_id: @inviter_id,
      repo_host: "github",
      token: "token"
    )

    :ok
  end

  describe "inject_provider_uid" do
    test "returns empty list for empty list" do
      assert Invitees.inject_provider_uid([], @inviter_id) == {:ok, []}
    end

    test "returns invitee when uid is present" do
      invitee = %{provider: %{uid: "foo", type: :GITHUB}}

      assert Invitees.inject_provider_uid(invitee, @inviter_id) == {:ok, invitee}
    end

    test "returns invitees when uid is present" do
      invitees = [
        %{provider: %{uid: "foo", type: :GITHUB}},
        %{provider: %{uid: "bar", type: :BITBUCKET}}
      ]

      assert Invitees.inject_provider_uid(invitees, @inviter_id) == {:ok, invitees}
    end

    test "skip injecting when provider is different then github" do
      invitee = %{provider: %{uid: "", type: :BITBUCKET}}

      assert Invitees.inject_provider_uid(invitee, @inviter_id) ==
               {:error, "provider BITBUCKET not supported"}
    end

    test "inject uid from db when it's present there" do
      Guard.FrontRepo.delete_all(Guard.FrontRepo.RepoHostAccount)

      Support.Members.insert_repo_host_account(
        login: "foo",
        github_uid: "111",
        user_id: Ecto.UUID.generate(),
        repo_host: "github"
      )

      invitee = %{provider: %{login: "foo", uid: "", type: :GITHUB}}

      invitee_with_uid = %{
        provider: %{login: "foo", uid: "111", type: :GITHUB}
      }

      assert Invitees.inject_provider_uid(invitee, @inviter_id) == {:ok, invitee_with_uid}
    end

    test "inject uid for github provider" do
      invitee = %{provider: %{login: "radwo", uid: "", type: :GITHUB}}

      invitee_with_uid = %{
        provider: %{login: "radwo", uid: "184065", type: :GITHUB}
      }

      response_body = Jason.encode!(%{"id" => 184_065})

      with_mocks([
        {Guard.FrontRepo.RepoHostAccount, [:passthrough],
         get_github_token: fn _ -> {:ok, {"token", nil}} end},
        {HTTPoison, [:passthrough],
         get: fn url, headers ->
           assert url == "https://api.github.com/users/radwo"
           assert headers == [{"Authorization", "Token token"}]
           {:ok, %{status_code: 200, body: response_body}}
         end}
      ]) do
        assert Invitees.inject_provider_uid(invitee, @inviter_id) == {:ok, invitee_with_uid}
      end
    end

    test "falls back to github api without inviter token" do
      Guard.FrontRepo.delete_all(Guard.FrontRepo.RepoHostAccount)

      invitee = %{provider: %{login: "radwo", uid: "", type: :GITHUB}}
      response_body = Jason.encode!(%{"id" => 123})

      log =
        capture_log(fn ->
          with_mock HTTPoison, [:passthrough],
            get: fn url, headers ->
              assert url == "https://api.github.com/users/radwo"
              assert headers == []
              {:ok, %{status_code: 200, body: response_body}}
            end do
            invitee_with_uid = %{
              provider: %{login: "radwo", uid: "123", type: :GITHUB}
            }

            assert Invitees.inject_provider_uid(invitee, @inviter_id) == {:ok, invitee_with_uid}
          end
        end)

      assert log =~ "Missing RHA for inviter"
    end

    test "falls back to gitlab api without inviter token" do
      Guard.FrontRepo.delete_all(Guard.FrontRepo.RepoHostAccount)

      invitee = %{provider: %{login: "radwo_gitlab", uid: "", type: :GITLAB}}
      response_body = Jason.encode!(%{"id" => 456})

      log =
        capture_log(fn ->
          with_mock HTTPoison, [:passthrough],
            get: fn url, headers ->
              assert url == "https://gitlab.com/api/v4/users?username=radwo_gitlab"
              assert headers == []
              {:ok, %{status_code: 200, body: response_body}}
            end do
            invitee_with_uid = %{
              provider: %{login: "radwo_gitlab", uid: "456", type: :GITLAB}
            }

            assert Invitees.inject_provider_uid(invitee, @inviter_id) == {:ok, invitee_with_uid}
          end
        end)

      assert log =~ "Missing RHA for inviter"
    end

    test "return error for unknown github user" do
      invitee = %{provider: %{login: "unknown331123", uid: "", type: :GITHUB}}

      with_mocks([
        {Guard.FrontRepo.RepoHostAccount, [:passthrough],
         get_github_token: fn _ -> {:ok, {"token", nil}} end},
        {HTTPoison, [:passthrough],
         get: fn url, headers ->
           assert url == "https://api.github.com/users/unknown331123"
           assert headers == [{"Authorization", "Token token"}]
           {:ok, %{status_code: 404}}
         end}
      ]) do
        assert Invitees.inject_provider_uid(invitee, @inviter_id) ==
                 {:error, "error finding unknown331123: 404"}
      end
    end
  end
end
