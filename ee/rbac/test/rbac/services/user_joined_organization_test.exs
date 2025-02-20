defmodule Rbac.Services.UserJoinedOrganizationTest do
  use Rbac.RepoCase
  import Ecto.Query

  setup do
    {:ok, user} = Support.Factories.RbacUser.insert()
    org_id = Ecto.UUID.generate()

    # In order for rbac sync to work, we must create a "Member" role
    {:ok, org_scope} = Support.Factories.Scope.insert("org_scope")

    {:ok, org_member_role} =
      Support.Factories.RbacRole.insert(
        scope_id: org_scope.id,
        org_id: org_id,
        name: "Member"
      )

    {:ok,
     %{
       user_id: user.id,
       org_id: org_id,
       org_member_role: org_member_role.id
     }}
  end

  describe ".handle_message" do
    test "user joined enterprise organization with custom roles", state do
      publish_event(state.user_id, state.org_id)

      :timer.sleep(300)

      assert Rbac.Repo.SubjectRoleBinding
             |> where(
               [srb],
               srb.org_id == ^state.org_id and
                 srb.subject_id == ^state.user_id and
                 srb.role_id == ^state.org_member_role
             )
             |> Rbac.Repo.one() != nil
    end
  end

  #
  # Helpers
  #

  def publish_event(user_id, org_id) do
    event = %InternalApi.User.UserJoinedOrganization{user_id: user_id, org_id: org_id}

    message = InternalApi.User.UserJoinedOrganization.encode(event)

    options = %{
      url: Application.get_env(:rbac, :amqp_url),
      exchange: "user_exchange",
      routing_key: "user_joined_organization"
    }

    Tackle.publish(message, options)
  end
end
