defmodule Rbac.Service.OrganizationCreated.Test do
  use Rbac.RepoCase
  import Ecto.Query

  @new_org_id "4bf77a6a-f567-477b-8cb4-d6da06237048"
  @creator_id "1819cd70-e040-4ed6-98fa-f528ea5d388f"

  describe ".handle_message" do
    test "message processing when the server is avaible" do
      Support.Factories.Scope.insert("org_scope")
      Support.Factories.Scope.insert("project_scope")
      Rbac.Repo.Permission.insert_default_permissions()

      %Rbac.FrontRepo.Organization{id: @new_org_id, creator_id: @creator_id}
      |> Rbac.FrontRepo.insert()

      Support.Factories.RbacUser.insert(@creator_id)

      publish_event(@new_org_id)

      :timer.sleep(300)

      role_assignment =
        Rbac.Repo.SubjectRoleBinding
        |> where(
          [srb],
          srb.org_id == ^@new_org_id and srb.subject_id == ^@creator_id
        )
        |> Rbac.Repo.one()

      assert role_assignment != nil

      assigned_role =
        Rbac.Repo.RbacRole |> where([r], r.id == ^role_assignment.role_id) |> Rbac.Repo.one()

      assert assigned_role.name == "Owner"
      assert assigned_role.org_id == @new_org_id
    end
  end

  #
  # Helpers
  #

  defp publish_event(org_id) do
    event = %InternalApi.Organization.OrganizationCreated{org_id: org_id}

    message = InternalApi.Organization.OrganizationCreated.encode(event)

    options = %{
      url: Application.get_env(:rbac, :amqp_url),
      exchange: "organization_exchange",
      routing_key: "created"
    }

    Tackle.publish(message, options)
  end
end
