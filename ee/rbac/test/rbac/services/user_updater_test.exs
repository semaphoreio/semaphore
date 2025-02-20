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
  end

  #
  # Helpers
  #

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
