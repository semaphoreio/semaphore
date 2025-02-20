defmodule Rbac.Services.OrganizationDeletedTest do
  use ExUnit.Case
  use Rbac.RepoCase

  @org_id Ecto.UUID.generate()

  describe ".handle_message" do
    test "message processing when the server is available" do
      role_assignments = [
        %{
          org_id: @org_id,
          user_id: Ecto.UUID.generate(),
          role_id: Rbac.Roles.Member.role().id,
          project_ids: [
            Ecto.UUID.generate(),
            Ecto.UUID.generate()
          ]
        },
        %{
          org_id: @org_id,
          user_id: Ecto.UUID.generate(),
          role_id: Rbac.Roles.Admin.role().id,
          project_ids: []
        },
        %{
          org_id: @org_id,
          user_id: Ecto.UUID.generate(),
          role_id: Rbac.Roles.Owner.role().id,
          project_ids: []
        }
      ]

      role_assignments
      |> Enum.each(fn role_assignment ->
        Rbac.Support.RoleAssignmentsFixtures.role_assignment_fixture(%{
          user_id: role_assignment.user_id,
          role_id: role_assignment.role_id,
          org_id: role_assignment.org_id
        })

        role_assignment.project_ids
        |> Enum.each(fn project_id ->
          Rbac.Support.ProjectAssignmentsFixtures.project_assignment_fixture(%{
            user_id: role_assignment.user_id,
            project_id: project_id,
            org_id: role_assignment.org_id
          })
        end)
      end)

      {:module, consumer, _, _} =
        Support.TestConsumer.create_test_consumer(
          self(),
          Application.get_env(:rbac, :amqp_url),
          "organization_exchange",
          "deleted_test",
          "rbac.organization_deleted",
          Rbac.Services.OrganizationDeleted
        )

      {:ok, _} = consumer.start_link()

      publish_event(@org_id)

      assert_receive {:ok, Rbac.Services.OrganizationDeleted}, 5_000

      role_assignments
      |> Enum.each(fn role_assignment ->
        assert Rbac.Models.RoleAssignment.get_by_user_and_org_id(
                 role_assignment.user_id,
                 role_assignment.org_id
               ) == nil
      end)

      project_id_assignments =
        role_assignments
        |> Enum.flat_map(fn role_assignment ->
          role_assignment.project_ids |> Enum.map(fn id -> {id, role_assignment.user_id} end)
        end)

      project_id_assignments
      |> Enum.each(fn {project_id, user_id} ->
        assert Rbac.Models.ProjectAssignment.get_by_user_and_project_id(
                 user_id,
                 project_id
               ) == nil
      end)
    end
  end

  defp publish_event(org_id) do
    event = %InternalApi.Organization.OrganizationDeleted{org_id: org_id}

    message = InternalApi.Organization.OrganizationDeleted.encode(event)

    options = %{
      url: Application.get_env(:rbac, :amqp_url),
      exchange: "organization_exchange",
      routing_key: "deleted_test"
    }

    Tackle.publish(message, options)
  end
end
