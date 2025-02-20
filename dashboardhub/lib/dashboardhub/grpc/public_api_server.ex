defmodule Dashboardhub.Grpc.PublicApiServer do
  require Logger

  use GRPC.Server, service: Semaphore.Dashboards.V1alpha.DashboardsApi.Service

  alias Semaphore.Dashboards.V1alpha.{
    ListDashboardsResponse,
    Empty
  }

  alias Dashboardhub.{Store, Utils, Auth, Event}

  def list_dashboards(req, call) do
    Watchman.benchmark("dashboardhub.list_dashboard.duration", fn ->
      alias Dashboardhub.PublicGrpcApi.ListDashboards, as: LD

      {org_id, user_id} = call |> extract_headers

      Logger.info("Listing #{inspect(org_id)} #{inspect(user_id)} #{inspect(req)}")

      with {:ok, page_size} <- LD.extract_page_size(req),
           {:ok, :authorized} <- Auth.authorize(:LIST, org_id, user_id),
           {:ok, dashboards, next_page_token} <- LD.query(org_id, page_size, req.page_token) do
        %ListDashboardsResponse{
          dashboards: encode(dashboards),
          next_page_token: next_page_token
        }
      else
        # {:error, :permission_denied, message} ->
        #   raise GRPC.RPCError, status: :permission_denied, message: message

        {:error, :precondition_failed, message} ->
          raise GRPC.RPCError, status: :invalid_argument, message: message
      end
    end)
  end

  def get_dashboard(req, call) do
    {org_id, user_id} = call |> extract_headers

    Logger.info("Get Dashboard #{inspect(org_id)} #{inspect(user_id)} #{inspect(req)}")

    id_or_name = req.id_or_name

    with {:ok, dashboard} <- Store.get(org_id, id_or_name),
         {:ok, :authorized} <- Auth.authorize(:READ, dashboard.id, user_id, org_id) do
      encode(dashboard)
    else
      # {:error, :permission_denied} ->
      #   raise GRPC.RPCError, status: :not_found, message: "Dashboard #{id_or_name} not found"

      {:error, :not_found} ->
        raise GRPC.RPCError, status: :not_found, message: "Dashboard #{id_or_name} not found"

      {:error, :unknown, message} ->
        raise GRPC.RPCError, status: :unknown, message: message
    end
  end

  def create_dashboard(dashboard, call) do
    {org_id, user_id} = call |> extract_headers

    name = dashboard.metadata.name
    content = Utils.proto_to_record(dashboard)

    Logger.info(
      "Create Dashboard #{inspect(org_id)} #{inspect(user_id)} #{inspect(name)} #{inspect(content)}"
    )

    with {:ok, :authorized} <- Auth.authorize(:CREATE, user_id, org_id),
         {:ok, :valid} <- Utils.valid_widgets?(dashboard),
         {:ok, dashboard} <- Store.save(org_id, name, content),
         {:ok, nil} <- Event.publish("created", dashboard.id, org_id) do
      encode(dashboard)
    else
      # {:error, :permission_denied} ->
      #   raise GRPC.RPCError,
      #     status: :permission_denied,
      #     message: "You are not authorized to create dashboard"

      {:error, :failed_precondition, message} ->
        raise GRPC.RPCError, status: :invalid_argument, message: message

      {:error, :unknown, message} ->
        raise GRPC.RPCError, status: :unknown, message: message

      {:error, :invalid_widgets, message} ->
        raise GRPC.RPCError, status: :invalid_argument, message: message
    end
  end

  def update_dashboard(req, call) do
    {org_id, user_id} = call |> extract_headers

    id_or_name = req.id_or_name

    new_name = req.dashboard.metadata.name
    new_content = Utils.proto_to_record(req.dashboard)

    Logger.info(
      "Update Dashboard #{inspect(org_id)} #{inspect(user_id)} #{inspect(id_or_name)} #{inspect(new_content)}"
    )

    with {:ok, dashboard} <- Store.get(org_id, id_or_name),
         {:ok, :authorized} <- Auth.authorize(:UPDATE, dashboard.id, user_id, org_id),
         {:ok, :valid} <- Utils.valid_widgets?(req.dashboard),
         {:ok, new_dashboard} <- Store.update(org_id, dashboard, new_name, new_content),
         {:ok, nil} <- Event.publish("updated", dashboard.id, org_id) do
      encode(new_dashboard)
    else
      {:error, :failed_precondition, message} ->
        raise GRPC.RPCError, status: :invalid_argument, message: message

      {:error, :not_found} ->
        raise GRPC.RPCError, status: :not_found, message: "Dashboard #{id_or_name} not found"

      {:error, :unknown, message} ->
        raise GRPC.RPCError, status: :unknown, message: message

      {:error, :invalid_widgets, message} ->
        raise GRPC.RPCError, status: :invalid_argument, message: message
    end
  end

  def delete_dashboard(req, call) do
    {org_id, user_id} = call |> extract_headers

    id_or_name = req.id_or_name

    Logger.info("Delete Dashboard #{inspect(org_id)} #{inspect(user_id)} #{inspect(id_or_name)}")

    with {:ok, dashboard} <- Store.get(org_id, id_or_name),
         {:ok, :authorized} <- Auth.authorize(:DELETE, dashboard.id, user_id, org_id),
         {:ok, _} <- Store.delete(dashboard),
         {:ok, nil} <- Event.publish("deleted", dashboard.id, org_id) do
      %Empty{}
    else
      # {:error, :permission_denied} ->
      #   raise GRPC.RPCError, status: :not_found, message: "Dashboard #{id_or_name} not found"

      {:error, :not_found} ->
        raise GRPC.RPCError, status: :not_found, message: "Dashboard #{id_or_name} not found"

      {:error, :unknown, message} ->
        raise GRPC.RPCError, status: :unknown, message: message
    end
  end

  defp extract_headers(call) do
    call
    |> GRPC.Stream.get_headers()
    |> Map.take(["x-semaphore-org-id", "x-semaphore-user-id"])
    |> Map.values()
    |> List.to_tuple()
  end

  def encode(records) when is_list(records) do
    records
    |> Enum.map(fn record -> encode(record) end)
  end

  def encode(record) do
    record
    |> Utils.record_to_proto()
  end
end
