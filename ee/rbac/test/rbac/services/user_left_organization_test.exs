defmodule Rbac.Services.UserLeftOrganizationTest do
  use Rbac.RepoCase
  import Ecto.Query

  setup do
    {:ok, user} = Support.Factories.RbacUser.insert()
    {:ok, user2} = Support.Factories.RbacUser.insert()
    org_id = Ecto.UUID.generate()

    # In order for rbac sync to work, we must create a "Member" role
    {:ok, org_scope} = Support.Factories.Scope.insert("org_scope")
    {:ok, project_scope} = Support.Factories.Scope.insert("project_scope")

    {:ok, org_member_role} =
      Support.Factories.RbacRole.insert(
        scope_id: org_scope.id,
        org_id: Rbac.Utils.Common.nil_uuid(),
        name: "Member"
      )

    {:ok, project_contributor_role} =
      Support.Factories.RbacRole.insert(
        scope_id: project_scope.id,
        org_id: Rbac.Utils.Common.nil_uuid(),
        name: "Contributor"
      )

    {:ok,
     %{
       user_id: user.id,
       user2_id: user2.id,
       org_id: org_id,
       org_member_role: org_member_role.id,
       project_contributor_role: project_contributor_role.id
     }}
  end

  describe ".handle_message" do
    test "user removed from organization", state do
      Support.Factories.SubjectRoleBinding.insert(
        subject_id: state.user_id,
        org_id: state.org_id,
        role_id: state.org_member_role
      )

      Support.Factories.SubjectRoleBinding.insert(
        subject_id: state.user2_id,
        org_id: state.org_id,
        role_id: state.org_member_role
      )

      Support.Factories.SubjectRoleBinding.insert(
        subject_id: state.user_id,
        org_id: state.org_id,
        project_id: Ecto.UUID.generate(),
        role_id: state.project_contributor_role
      )

      Support.Factories.SubjectRoleBinding.insert(
        subject_id: state.user_id,
        org_id: Ecto.UUID.generate(),
        role_id: state.org_member_role
      )

      publish_event(state.user_id, state.org_id)

      :timer.sleep(300)

      assert Rbac.Repo.SubjectRoleBinding |> Rbac.Repo.all() |> length == 2

      assert Rbac.Repo.SubjectRoleBinding
             |> where(
               [srb],
               srb.org_id == ^state.org_id and
                 srb.subject_id == ^state.user_id
             )
             |> Rbac.Repo.all()
             |> length() == 0
    end
  end

  #
  # Helpers
  #

  def publish_event(user_id, org_id) do
    event = %InternalApi.User.UserLeftOrganization{user_id: user_id, org_id: org_id}

    message = InternalApi.User.UserLeftOrganization.encode(event)

    options = %{
      url: Application.get_env(:rbac, :amqp_url),
      exchange: "user_exchange",
      routing_key: "user_left_organization"
    }

    Tackle.publish(message, options)
  end
end
