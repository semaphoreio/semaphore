defmodule Rbac.Services.ProjectDeletedTest do
  use ExUnit.Case
  use Rbac.RepoCase
  import Ecto.Query

  @deleting_project_id Ecto.UUID.generate()
  @org_id Ecto.UUID.generate()

  describe ".handle_message" do
    test "message processing when the server is available" do
      role_assignment =
        %{
          org_id: @org_id,
          user_id: Ecto.UUID.generate(),
          role_id: Rbac.Roles.Member.role().id,
          project_ids: [
            @deleting_project_id,
            Ecto.UUID.generate()
          ]
        }

      Rbac.Support.RoleAssignmentsFixtures.role_assignment_fixture(%{
        user_id: role_assignment.user_id,
        role_id: role_assignment.role_id,
        org_id: role_assignment.org_id
      })

      role_assignment.project_ids
      |> Enum.each(fn project_id ->
        Rbac.Support.ProjectAssignmentsFixtures.project_assignment_fixture(%{
          org_id: role_assignment.org_id,
          user_id: role_assignment.user_id,
          project_id: project_id
        })
      end)

      project_id =
        role_assignment.project_ids
        |> Enum.find(fn project_id -> project_id == @deleting_project_id end)

      {:module, consumer, _, _} =
        Support.TestConsumer.create_test_consumer(
          self(),
          Application.get_env(:rbac, :amqp_url),
          "project_exchange",
          "deleted_test",
          "rbac.project_deleted",
          Rbac.Services.ProjectDeleted
        )

      {:ok, _} = consumer.start_link()

      publish_event(project_id)

      assert_receive {:ok, Rbac.Services.ProjectDeleted}, 5_000

      project_assignments =
        Rbac.Models.ProjectAssignment
        |> where([pa], pa.project_id == ^project_id)
        |> Rbac.Repo.all()

      assert project_assignments == []
    end
  end

  defp publish_event(project_id) do
    event = %InternalApi.Projecthub.ProjectDeleted{
      project_id: project_id
    }

    options = %{
      url: Application.get_env(:rbac, :amqp_url),
      exchange: "project_exchange",
      routing_key: "deleted_test"
    }

    message = InternalApi.Projecthub.ProjectDeleted.encode(event)

    Tackle.publish(message, options)
  end
end
