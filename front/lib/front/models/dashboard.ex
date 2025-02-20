defmodule Front.Models.Dashboard do
  defstruct [:id, :name, :widgets, :title]

  require Logger

  alias Semaphore.Dashboards.V1alpha.{
    DashboardsApi,
    GetDashboardRequest,
    ListDashboardsRequest
  }

  alias DashboardsApi.Stub

  def list(user_id, org_id) do
    Watchman.benchmark("list_dashboards.duration", fn ->
      req = ListDashboardsRequest.new()

      {:ok, response} =
        Watchman.benchmark("list_dashboards.api_call.duration", fn ->
          Stub.list_dashboards(channel(), req, options(user_id, org_id))
        end)

      Watchman.benchmark("list_dashboards.construct.duration", fn ->
        construct(response.dashboards)
      end)
    end)
  end

  def find(id, org_id, user_id) do
    Watchman.benchmark("fetch_dashboard.duration", fn ->
      req = GetDashboardRequest.new(id_or_name: id)

      case Stub.get_dashboard(channel(), req, options(user_id, org_id)) do
        {:error, msg} ->
          Watchman.increment("fetch_dashboard.failed")
          Logger.error("Failed GetDashboardRequest: #{inspect(msg)}")

          nil

        {:ok, res} ->
          construct(res)
      end
    end)
  end

  defp construct(dashboards) when is_list(dashboards) do
    dashboards |> Enum.map(fn dashboard -> construct(dashboard) end)
  end

  defp construct(dashboard) do
    %__MODULE__{
      :id => dashboard.metadata.id,
      :name => dashboard.metadata.name,
      :title => dashboard.metadata.title,
      :widgets => dashboard.spec.widgets |> transform_to_maps()
    }
  end

  defp transform_to_maps(widgets) do
    widgets
    |> Enum.map(fn widget ->
      widget
      |> Map.from_struct()
      |> Enum.map(fn {key, value} -> {Atom.to_string(key), value} end)
      |> Enum.into(%{})
    end)
  end

  defp channel do
    case GRPC.Stub.connect(Application.fetch_env!(:front, :dashboard_api_grpc_endpoint)) do
      {:ok, channel} -> channel
      # raise error ?
      _ -> nil
    end
  end

  defp options(user_id, org_id) do
    auth = %{"x-semaphore-org-id" => org_id, "x-semaphore-user-id" => user_id}

    [timeout: 30_000, metadata: auth]
  end
end
