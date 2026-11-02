defmodule Rbac.Api.OIDCTest do
  use Rbac.RepoCase

  import Mock

  defp tesla_client do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, "http://keycloak/manage"},
      Tesla.Middleware.JSON
    ])
  end

  setup do
    Support.Rbac.Store.clear!()
    Rbac.FrontRepo.delete_all(Rbac.FrontRepo.RepoHostAccount)

    :ok
  end

  test "includes gitlab federated identity for connected gitlab account" do
    {:ok, user} = Support.Factories.RbacUser.insert()

    {:ok, _} =
      Support.Members.insert_repo_host_account(
        login: "gitlab_user",
        github_uid: "123",
        user_id: user.id,
        repo_host: "gitlab"
      )

    data = Rbac.Api.OIDC.get_oidc_data(user)

    assert Enum.any?(data.federatedIdentities, fn identity ->
             identity.identityProvider == "gitlab" and identity.userId == "123"
           end)
  end

  test "includes github and bitbucket federated identities when bitbucket is connected" do
    {:ok, user} = Support.Factories.RbacUser.insert()

    {:ok, _} =
      Support.Members.insert_repo_host_account(
        login: "radwo",
        github_uid: "184065",
        user_id: user.id,
        repo_host: "github"
      )

    {:ok, _} =
      Support.Members.insert_repo_host_account(
        login: "radwo",
        github_uid: "bitbucket-uid",
        user_id: user.id,
        repo_host: "bitbucket"
      )

    with_mock Rbac.Api.Bitbucket, [:passthrough],
      user: fn "bitbucket-uid" -> {:ok, %{account_id: "bitbucket-account"}} end do
      data = Rbac.Api.OIDC.get_oidc_data(user)

      assert Enum.any?(data.federatedIdentities, fn identity ->
               identity.identityProvider == "github" and identity.userId == "184065"
             end)

      assert Enum.any?(data.federatedIdentities, fn identity ->
               identity.identityProvider == "bitbucket" and
                 identity.userId == "bitbucket-account"
             end)
    end
  end

  describe "create_oidc_user/3 failure logging" do
    test "a rejected creation does not log the credential payload" do
      password = "correct-horse-battery-staple"
      user = %{id: Ecto.UUID.generate(), name: "Octo Cat", email: "octo@example.com"}

      Tesla.Mock.mock(fn %{method: :post} ->
        {:ok,
         %Tesla.Env{status: 409, body: %{"errorMessage" => "User exists with same username"}}}
      end)

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          assert {:error, _} =
                   Rbac.Api.OIDC.create_oidc_user(tesla_client(), user,
                     password_data: [password: password]
                   )
        end)

      assert log =~ "octo@example.com"
      refute log =~ "secretData"
      refute log =~ password
    end
  end
end
