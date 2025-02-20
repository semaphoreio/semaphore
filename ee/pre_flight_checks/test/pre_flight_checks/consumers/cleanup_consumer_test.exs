defmodule PreFlightChecks.Consumers.CleanupConsumerTest do
  use ExUnit.Case

  alias PreFlightChecks.DestroyTraces.DestroyTrace, as: Trace
  alias PreFlightChecks.OrganizationPFC.Model.OrganizationPFCQueries
  alias PreFlightChecks.ProjectPFC.Model.ProjectPFCQueries

  alias PreFlightChecks.EctoRepo

  setup_all [:setup_amqp_channel]
  setup [:ecto_checkout]

  describe "Consumers.CleanupConsumer for organization_exchange" do
    setup [:setup_org_pfc]

    test "when OrganizationDeleted received then removes organization pre-flight checks",
         %{channel: channel, organization_id: organization_id} do
      assert {:ok, %{organization_id: ^organization_id}} =
               OrganizationPFCQueries.find(organization_id)

      exchange = Tackle.Exchange.create(channel, "organization_exchange")
      timestamp = %{seconds: DateTime.utc_now() |> DateTime.to_unix()}

      message =
        InternalApi.Organization.OrganizationDeleted
        |> Util.Proto.deep_new!(%{
          org_id: organization_id,
          timestamp: timestamp
        })
        |> InternalApi.Organization.OrganizationDeleted.encode()

      Tackle.Exchange.publish(channel, exchange, message, "deleted")
      Process.sleep(500)

      assert %Trace{
               organization_id: ^organization_id,
               level: :ORGANIZATION,
               requester_id: "organization_deleted_event",
               status: :SUCCESS
             } = Trace |> EctoRepo.all() |> List.first()

      assert {:error, {:not_found, ^organization_id}} =
               OrganizationPFCQueries.find(organization_id)
    end

    test "when any other message received then there are no side effects",
         %{channel: channel, organization_id: organization_id} do
      assert {:ok, %{organization_id: ^organization_id}} =
               OrganizationPFCQueries.find(organization_id)

      pid = Process.whereis(PreFlightChecks.Consumers.CleanupConsumer)
      exchange = Tackle.Exchange.create(channel, "organization_exchange")
      Tackle.Exchange.publish(channel, exchange, "foo", "deleted")

      assert ^pid = Process.whereis(PreFlightChecks.Consumers.CleanupConsumer)

      assert {:ok, %{organization_id: ^organization_id}} =
               OrganizationPFCQueries.find(organization_id)
    end
  end

  describe "Consumers.CleanupConsumer for project_exchange" do
    setup [:setup_prj_pfc]

    test "when ProjectDeleted received then removes project pre-flight checks",
         %{channel: channel, organization_id: organization_id, project_id: project_id} do
      assert {:ok, %{project_id: ^project_id}} = ProjectPFCQueries.find(project_id)

      exchange = Tackle.Exchange.create(channel, "project_exchange")
      timestamp = %{seconds: DateTime.utc_now() |> DateTime.to_unix()}

      message =
        InternalApi.Projecthub.ProjectDeleted
        |> Util.Proto.deep_new!(%{
          org_id: organization_id,
          project_id: project_id,
          timestamp: timestamp
        })
        |> InternalApi.Projecthub.ProjectDeleted.encode()

      Tackle.Exchange.publish(channel, exchange, message, "deleted")
      Process.sleep(500)

      assert %Trace{
               project_id: ^project_id,
               level: :PROJECT,
               requester_id: "project_deleted_event",
               status: :SUCCESS
             } = Trace |> EctoRepo.all() |> List.first()

      assert {:error, {:not_found, ^project_id}} = ProjectPFCQueries.find(project_id)
    end

    test "when any other message received then there are no side effects",
         %{channel: channel, project_id: project_id} do
      assert {:ok, %{project_id: ^project_id}} = ProjectPFCQueries.find(project_id)

      pid = Process.whereis(PreFlightChecks.Consumers.CleanupConsumer)
      exchange = Tackle.Exchange.create(channel, "project_exchange")
      Tackle.Exchange.publish(channel, exchange, "foo", "deleted")

      assert ^pid = Process.whereis(PreFlightChecks.Consumers.CleanupConsumer)
      assert {:ok, %{project_id: ^project_id}} = ProjectPFCQueries.find(project_id)
    end
  end

  defp setup_amqp_channel(_context) do
    url = Application.get_env(:pre_flight_checks, :amqp_url)

    with {:ok, connection} <- AMQP.Connection.open(url),
         {:ok, channel} <- AMQP.Channel.open(connection) do
      on_exit(fn ->
        AMQP.Connection.close(connection)
      end)

      {:ok, %{channel: channel}}
    end
  end

  defp ecto_checkout(_context) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(PreFlightChecks.EctoRepo, shared: true)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  defp setup_org_pfc(_context) do
    params = %{
      organization_id: UUID.uuid4(),
      requester_id: UUID.uuid4(),
      definition: %{
        commands: [
          "git checkout master",
          "make install"
        ],
        secrets: ["SESSION_SECRET"],
        agent: %{
          machine_type: "e1-standard-2",
          os_image: "ubuntu1804"
        }
      }
    }

    {:ok, pfc} = OrganizationPFCQueries.upsert(params)
    [organization_id: pfc.organization_id]
  end

  defp setup_prj_pfc(_context) do
    params = %{
      organization_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      requester_id: UUID.uuid4(),
      definition: %{
        commands: [
          "git checkout master",
          "make install"
        ],
        secrets: ["SESSION_SECRET"]
      }
    }

    {:ok, pfc} = ProjectPFCQueries.upsert(params)
    [organization_id: pfc.organization_id, project_id: pfc.project_id]
  end
end
