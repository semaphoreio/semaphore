defmodule Rbac.Services.UserUpdaterTest do
  use Rbac.RepoCase

  import Mock

  setup do
    Support.Rbac.Store.clear!()

    :ok
  end

  describe ".handle_message" do
    test "message processing when the server is available" do
      user_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()

      with_mock Rbac.RoleManagement, [:passthrough],
        assign_project_roles_to_repo_collaborators: fn rbi -> assert rbi.user_id == user_id end,
        assign_role: fn _, _, _ -> {:ok, nil} end do
        user = Support.Factories.user(user_id: user_id)

        {:ok, front_user} =
          %Rbac.FrontRepo.User{
            id: user.user_id,
            name: user.name,
            email: user.email
          }
          |> Rbac.FrontRepo.insert()

        invite_user_to_org(front_user.id, org_id)

        publish_event(user)

        :timer.sleep(1200)

        # Checking if sync with rbac is working
        assert_called_exactly(
          Rbac.RoleManagement.assign_project_roles_to_repo_collaborators(:_),
          1
        )

        assert_called_exactly(
          Rbac.RoleManagement.assign_role(:_, :_, :manually_assigned),
          1
        )
      end
    end

    test "updates oidc user with gitlab identity when gitlab is connected" do
      Rbac.Mocks.OpenIDConnect.stub_oidc_connection()

      user_id = Ecto.UUID.generate()
      oidc_user_id = Ecto.UUID.generate()

      {:ok, _} = Support.Factories.RbacUser.insert(user_id, "Gitlab User", "gitlab@example.com")
      {:ok, _} = Support.Factories.OIDCUser.insert(user_id, oidc_user_id)

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "github_user",
          github_uid: "184065",
          user_id: user_id,
          repo_host: "github"
        )

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "gitlab_user",
          github_uid: "123",
          user_id: user_id,
          repo_host: "gitlab"
        )

      setup_tesla_mock(oidc_user_id)

      with_mocks [
        {Rbac.RoleManagement, [:passthrough],
         assign_project_roles_to_repo_collaborators: fn _ -> :ok end,
         assign_role: fn _, _, _ -> {:ok, nil} end},
        {Rbac.ProviderRefresher, [:passthrough], refresh: fn _ -> :ok end},
        {Rbac.TempSync, [:passthrough], sync_new_user_with_members_table: fn _ -> :ok end}
      ] do
        message =
          %InternalApi.User.UserUpdated{user_id: user_id}
          |> InternalApi.User.UserUpdated.encode()

        Rbac.Services.UserUpdater.handle_message(message)
      end

      assert_receive {:oidc_put, body}, 5_000

      body = decode_json_body(body)

      assert Enum.any?(body["federatedIdentities"], fn identity ->
               identity["identityProvider"] == "gitlab" and identity["userId"] == "123"
             end)

      assert Enum.any?(body["federatedIdentities"], fn identity ->
               identity["identityProvider"] == "github" and identity["userId"] == "184065"
             end)
    end

    test "updates oidc user with bitbucket identity when bitbucket is connected" do
      Rbac.Mocks.OpenIDConnect.stub_oidc_connection()

      user_id = Ecto.UUID.generate()
      oidc_user_id = Ecto.UUID.generate()

      {:ok, _} =
        Support.Factories.RbacUser.insert(user_id, "Bitbucket User", "bitbucket@example.com")

      {:ok, _} = Support.Factories.OIDCUser.insert(user_id, oidc_user_id)

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "github_user",
          github_uid: "184065",
          user_id: user_id,
          repo_host: "github"
        )

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "bitbucket_user",
          github_uid: "bitbucket-uid",
          user_id: user_id,
          repo_host: "bitbucket"
        )

      setup_tesla_mock(oidc_user_id)

      with_mocks [
        {Rbac.Api.Bitbucket, [:passthrough],
         user: fn "bitbucket-uid" -> {:ok, %{account_id: "bitbucket-account"}} end},
        {Rbac.RoleManagement, [:passthrough],
         assign_project_roles_to_repo_collaborators: fn _ -> :ok end,
         assign_role: fn _, _, _ -> {:ok, nil} end},
        {Rbac.ProviderRefresher, [:passthrough], refresh: fn _ -> :ok end},
        {Rbac.TempSync, [:passthrough], sync_new_user_with_members_table: fn _ -> :ok end}
      ] do
        message =
          %InternalApi.User.UserUpdated{user_id: user_id}
          |> InternalApi.User.UserUpdated.encode()

        Rbac.Services.UserUpdater.handle_message(message)
      end

      assert_receive {:oidc_put, body}, 5_000

      body = decode_json_body(body)

      assert Enum.any?(body["federatedIdentities"], fn identity ->
               identity["identityProvider"] == "bitbucket" and
                 identity["userId"] == "bitbucket-account"
             end)
    end
  end

  #
  # Helpers
  #

  defp setup_tesla_mock(oidc_user_id) do
    test_pid = self()

    Tesla.Mock.mock_global(fn
      %{method: :put, url: url, body: body} ->
        if String.contains?(url, "/users/#{oidc_user_id}") do
          send(test_pid, {:oidc_put, body})
        end

        {:ok, %Tesla.Env{status: 200, body: %{}}}

      %{method: :post, url: url, body: body} ->
        if String.contains?(url, "/users/#{oidc_user_id}/federated-identity/") do
          send(test_pid, {:oidc_post, url, body})
        end

        {:ok, %Tesla.Env{status: 200, body: %{}}}

      %{method: :delete} ->
        {:ok, %Tesla.Env{status: 204, body: %{}}}
    end)
  end

  defp decode_json_body(body) when is_binary(body), do: Jason.decode!(body)
  defp decode_json_body(body), do: body

  def publish_event(user) do
    event = %InternalApi.User.UserUpdated{user_id: user.user_id}

    message = InternalApi.User.UserUpdated.encode(event)

    options = %{
      url: Application.get_env(:rbac, :amqp_url),
      exchange: "user_exchange",
      routing_key: "updated"
    }

    Tackle.publish(message, options)
  end

  defp invite_user_to_org(user_id, org_id) do
    {:ok, _repo_host_account} =
      Support.Members.insert_repo_host_account(
        login: "radwo",
        repo_host: "github",
        refresh_token: "example_refresh_token",
        user_id: user_id,
        permission_scope: "repo",
        github_uid: "184065"
      )

    {:ok, _} =
      Support.Members.insert_member(
        github_username: "radwo",
        github_uid: "184065",
        organization_id: org_id
      )
  end
end
