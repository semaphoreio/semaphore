defmodule Rbac.Services.UserDeletedTest do
  use ExUnit.Case
  use Rbac.RepoCase

  @user_id Ecto.UUID.generate()
  @org_id Ecto.UUID.generate()

  describe ".handle_message" do
    test "message processing when the server is available" do
      Rbac.Support.RoleAssignmentsFixtures.role_assignment_fixture(%{
        user_id: @user_id,
        role_id: Rbac.Roles.Member.role().id,
        org_id: @org_id
      })

      # assign projects assignments
      1..3
      |> Enum.each(fn _ ->
        Rbac.Support.ProjectAssignmentsFixtures.project_assignment_fixture(%{
          user_id: @user_id,
          project_id: Ecto.UUID.generate(),
          org_id: @org_id
        })
      end)

      {:module, consumer, _, _} =
        Support.TestConsumer.create_test_consumer(
          self(),
          Application.get_env(:rbac, :amqp_url),
          "user_exchange",
          "deleted_test",
          "rbac.user_deleted",
          Rbac.Services.UserDeleted
        )

      {:ok, _} = consumer.start_link()

      publish_event(@user_id)

      assert_receive {:ok, Rbac.Services.UserDeleted}, 5_000

      role_assignment = Rbac.Models.RoleAssignment.get_by_user_and_org_id(@user_id, @org_id)
      assert role_assignment == nil

      project_assignments =
        Rbac.Models.ProjectAssignment.get_by_user_and_org_id(@user_id, @org_id)

      assert project_assignments == []
    end
  end

  defp publish_event(user_id) do
    event = %InternalApi.User.UserDeleted{user_id: user_id}

    message = InternalApi.User.UserDeleted.encode(event)

    options = %{
      url: Application.get_env(:rbac, :amqp_url),
      exchange: "user_exchange",
      routing_key: "deleted_test"
    }

    Tackle.publish(message, options)
  end
end
