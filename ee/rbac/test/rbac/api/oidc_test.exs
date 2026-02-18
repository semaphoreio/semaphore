defmodule Rbac.Api.OIDCTest do
  use Rbac.RepoCase

  import Mock

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
end
