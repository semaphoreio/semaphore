defmodule Support.Stubs.Dashboards do
  alias Support.Stubs.{DB, UUID}

  def init do
    DB.add_table(:dashboards, [:id, :org_id, :name, :api_model])

    __MODULE__.Grpc.init()
  end

  def create(org, params \\ []) do
    dashboard = build(org, params)

    DB.insert(:dashboards, %{
      id: dashboard.metadata.id,
      org_id: org.id,
      name: dashboard.metadata.name,
      api_model: dashboard
    })
  end

  def build(org, params \\ []) do
    alias InternalApi.Dashboardhub.Dashboard

    defaults = [
      id: UUID.gen(),
      widgets: nil,
      filters: %{}
    ]

    params = defaults |> Keyword.merge(params)

    meta = %Dashboard.Metadata{
      id: params[:id],
      title: "Dashboard 1",
      name: "dashboard-1",
      org_id: org.id,
      create_time: 1_549_885_252,
      update_time: 1_549_885_252
    }

    widgets = [
      %{
        name: "Widget 1",
        type: "list_workflows",
        filters: params[:filters]
      }
    ]

    spec = %Dashboard.Spec{
      widgets: params[:widgets] || widgets
    }

    %Dashboard{metadata: meta, spec: spec}
  end

  defmodule Grpc do
    def init do
      GrpcMock.stub(DashboardMock, :list, &__MODULE__.list/2)
      GrpcMock.stub(DashboardMock, :describe, &__MODULE__.describe/2)
      GrpcMock.stub(DashboardMock, :create, &__MODULE__.create/2)
      GrpcMock.stub(DashboardMock, :update, &__MODULE__.update/2)
      GrpcMock.stub(DashboardMock, :destroy, &__MODULE__.destroy/2)
    end

    def list(req, _call) do
      {org_id, _} = req |> extract_ids

      dashboards = org_dashboards(org_id) |> DB.extract(:api_model) |> Enum.take(req.page_size)

      %InternalApi.Dashboardhub.ListResponse{dashboards: dashboards, page_size: req.page_size}
    end

    def describe(req, _call) do
      case find(req) do
        {:ok, dashboard} ->
          %InternalApi.Dashboardhub.DescribeResponse{dashboard: dashboard.api_model}

        {:error, message} ->
          raise GRPC.RPCError, status: :not_found, message: message
      end
    end

    def create(req, _call) do
      {org_id, _} = req |> extract_ids

      id = UUID.gen()

      name =
        if req.dashboard.metadata.name != "" do
          req.dashboard.metadata.name
        else
          req.dashboard.metadata.title |> String.downcase() |> String.replace(~r/\s+/, "-")
        end

      case find(%{
             metadata: %{org_id: org_id, user_id: nil},
             id_or_name: req.dashboard.metadata.name
           }) do
        {:ok, _} ->
          raise GRPC.RPCError,
            status: :already_exists,
            message: "Dashboard #{name} already exists"

        _ ->
          DB.insert(:dashboards, %{id: id, name: name, org_id: org_id, api_model: req.dashboard})

          dashboard = %InternalApi.Dashboardhub.Dashboard{
            metadata: %InternalApi.Dashboardhub.Dashboard.Metadata{
              id: id,
              name: name,
              title: req.dashboard.metadata.title,
              org_id: req.metadata.org_id,
              create_time: req.dashboard.metadata.create_time,
              update_time: req.dashboard.metadata.update_time
            },
            spec: req.dashboard.spec
          }

          %InternalApi.Dashboardhub.CreateResponse{
            dashboard: dashboard
          }
      end
    end

    def update(req, _call) do
      case find(req) do
        {:ok, dashboard} ->
          entry =
            DB.update(
              :dashboards,
              %{
                id: dashboard.id,
                name: req.dashboard.metadata.name,
                org_id: dashboard.org_id,
                api_model: req.dashboard
              },
              id: dashboard.id
            )

          %InternalApi.Dashboardhub.UpdateResponse{
            dashboard: %InternalApi.Dashboardhub.Dashboard{
              metadata: %InternalApi.Dashboardhub.Dashboard.Metadata{
                id: entry.id,
                name: entry.name,
                org_id: req.dashboard.metadata.org_id,
                title: req.dashboard.metadata.title,
                create_time: req.dashboard.metadata.create_time,
                update_time: req.dashboard.metadata.update_time
              },
              spec: req.dashboard.spec
            }
          }

        {:error, message} ->
          raise GRPC.RPCError, status: 5, message: message
      end
    end

    def destroy(req, _call) do
      case find(req) do
        {:ok, dashboard} ->
          :ok = DB.delete(:dashboards, dashboard.id)
          %InternalApi.Dashboardhub.DestroyResponse{id: dashboard.id}

        {:error, message} ->
          raise GRPC.RPCError, status: 5, message: message
      end
    end

    defp org_dashboards(org_id) do
      DB.filter(:dashboards, org_id: org_id)
    end

    defp find(req) do
      {org_id, _} = req |> extract_ids

      case Enum.find(org_dashboards(org_id), fn d ->
             d.id == req.id_or_name || d.name == req.id_or_name
           end) do
        nil ->
          {:error, "Dashboard #{req.id_or_name} not found"}

        dashboard ->
          {:ok, dashboard}
      end
    end

    defp extract_ids(req) do
      {req.metadata.org_id, req.metadata.user_id}
    end
  end
end
