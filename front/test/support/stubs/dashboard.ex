defmodule Support.Stubs.Dashboard do
  alias Support.Stubs.{DB, UUID}

  def init do
    DB.add_table(:dashboards, [:id, :org_id, :name, :api_model])

    __MODULE__.Grpc.init()
  end

  def create(org) do
    alias Semaphore.Dashboards.V1alpha.Dashboard

    meta =
      Dashboard.Metadata.new(
        id: UUID.gen(),
        title: "Dashboard #1",
        name: "dashboard_1",
        create_time: 1_549_885_252,
        update_time: 1_549_885_252
      )

    spec =
      Dashboard.Spec.new(
        widgets: [
          Dashboard.Spec.Widget.new(
            name: "Widget 1",
            type: "list_workflows",
            filters: %{}
          )
        ]
      )

    api_model = Dashboard.new(metadata: meta, spec: spec)

    DB.insert(:dashboards, %{
      id: meta.id,
      org_id: org.id,
      name: meta.name,
      api_model: api_model
    })
  end

  defmodule Grpc do
    def init do
      GrpcMock.stub(DashboardMock, :list_dashboards, &__MODULE__.list_dashboards/2)
      GrpcMock.stub(DashboardMock, :get_dashboard, &__MODULE__.get_dashboard/2)
    end

    def list_dashboards(_req, call) do
      {org_id, _} = call |> extract_headers

      dashboards = org_dashboards(org_id) |> DB.extract(:api_model)

      Semaphore.Dashboards.V1alpha.ListDashboardsResponse.new(dashboards: dashboards)
    end

    def get_dashboard(req, call) do
      case find(req, call) do
        {:ok, dashboard} ->
          dashboard.api_model

        {:error, message} ->
          raise GRPC.RPCError, status: 5, message: message
      end
    end

    defp org_dashboards(org_id) do
      DB.filter(:dashboards, org_id: org_id)
    end

    defp find(req, call) do
      {org_id, _} = call |> extract_headers

      case Enum.find(org_dashboards(org_id), fn d ->
             d.id == req.id_or_name || d.name == req.id_or_name
           end) do
        nil ->
          {:error, "Dashboard #{req.id_or_name} not found"}

        dashboard ->
          {:ok, dashboard}
      end
    end

    defp extract_headers(call) do
      call
      |> GRPC.Stream.get_headers()
      |> Map.take(["x-semaphore-org-id", "x-semaphore-user-id"])
      |> Map.values()
      |> List.to_tuple()
    end
  end
end
