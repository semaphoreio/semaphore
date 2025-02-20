defmodule Rbac.Services.OrganizationCreatedTest do
  use ExUnit.Case
  use Rbac.RepoCase

  alias Rbac.Models.RoleAssignment

  import Rbac.Utils.Grpc, only: [grpc_error!: 2]

  setup do
    org_id = Ecto.UUID.generate()
    owner_id = Ecto.UUID.generate()

    organization = %InternalApi.Organization.Organization{
      org_id: org_id,
      org_username: "semaphore",
      name: "Semaphore",
      owner_id: owner_id
    }

    GrpcMock.stub(OrganizationMock, :describe, fn request, _ ->
      if request.org_id == org_id do
        %InternalApi.Organization.DescribeResponse{
          status: %InternalApi.ResponseStatus{code: :OK},
          organization: organization
        }
      else
        grpc_error!(:not_found, "Organization not found")
      end
    end)

    # Consumer will receive the message and send it to the test process
    {:module, consumer, _, _} =
      Support.TestConsumer.create_test_consumer(
        self(),
        Application.get_env(:rbac, :amqp_url),
        "organization_exchange",
        "created_test",
        "rbac.organization_created",
        Rbac.Services.OrganizationCreated
      )

    {:ok, _} = consumer.start_link()

    {:ok, org_id: org_id, owner_id: owner_id}
  end

  describe "handle_message/1" do
    test "assigns owner role when organization is created", %{org_id: org_id, owner_id: owner_id} do
      publish_event(org_id)

      assert_receive {:ok, Rbac.Services.OrganizationCreated}, 5_000

      # Assert that the owner role was assigned
      role_assignment = RoleAssignment.get_by_user_and_org_id(owner_id, org_id)
      assert role_assignment.role_id == Rbac.Roles.Owner.role().id
    end
  end

  defp publish_event(org_id) do
    message =
      %InternalApi.Organization.OrganizationCreated{
        org_id: org_id
      }
      |> InternalApi.Organization.OrganizationCreated.encode()

    options = %{
      url: Application.get_env(:rbac, :amqp_url),
      exchange: "organization_exchange",
      routing_key: "created_test"
    }

    Tackle.publish(message, options)
  end
end
