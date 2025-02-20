defmodule Dashboardhub.Grpc.InternalApiServer do
  require Logger

  use GRPC.Server, service: InternalApi.Dashboardhub.DashboardsService.Service

  alias Dashboardhub.{Store, Utils, Event}

  alias InternalApi.Dashboardhub.{
    ListResponse,
    DescribeResponse,
    CreateResponse,
    UpdateResponse,
    DestroyResponse
  }

  def list(req, _call) do
    Watchman.benchmark("dashboardhub.list.duration", fn ->
      alias Dashboardhub.PublicGrpcApi.ListDashboards, as: LD

      {org_id, user_id} = req |> extract_ids

      Logger.info("Listing #{inspect(org_id)} #{inspect(user_id)} #{inspect(req)}")

      with {:ok, page_size} <- LD.extract_page_size(req),
           {:ok, dashboards, next_page_token} <- LD.query(org_id, page_size, req.page_token) do
        %ListResponse{
          dashboards: encode(dashboards),
          next_page_token: next_page_token
        }
      else
        {:error, :precondition_failed, message} ->
          raise GRPC.RPCError, status: :invalid_argument, message: message
      end
    end)
  end

  def describe(req, _call) do
    {org_id, user_id} = req |> extract_ids

    Logger.info("Describe Dashboard #{inspect(org_id)} #{inspect(user_id)} #{inspect(req)}")

    id_or_name = req.id_or_name

    Store.get(org_id, id_or_name)
    |> case do
      {:ok, dashboard} ->
        %DescribeResponse{
          dashboard: encode(dashboard)
        }

      {:error, :not_found} ->
        raise GRPC.RPCError, status: :not_found, message: "Dashboard #{id_or_name} not found"

      {:error, :unknown, message} ->
        raise GRPC.RPCError, status: :unknown, message: message
    end
  end

  def create(create_req, _call) do
    {org_id, user_id} = create_req |> extract_ids

    dashboard = create_req.dashboard

    name = dashboard.metadata.name
    content = Utils.proto_to_record(dashboard)

    Logger.info(
      "Create Dashboard #{inspect(org_id)} #{inspect(user_id)} #{inspect(name)} #{inspect(content)}"
    )

    with {:ok, :valid} <- Utils.valid_widgets?(dashboard),
         {:ok, dashboard} <- Store.save(org_id, name, content),
         {:ok, nil} <- Event.publish("created", dashboard.id, org_id) do
      %CreateResponse{dashboard: encode(dashboard)}
    else
      {:error, :failed_precondition, message} ->
        raise GRPC.RPCError, status: :invalid_argument, message: message

      {:error, :unknown, message} ->
        raise GRPC.RPCError, status: :unknown, message: message

      {:error, :invalid_widgets, message} ->
        raise GRPC.RPCError, status: :invalid_argument, message: message
    end
  end

  def update(req, _call) do
    {org_id, user_id} = req |> extract_ids

    id_or_name = req.id_or_name

    new_name = req.dashboard.metadata.name
    new_content = Utils.proto_to_record(req.dashboard)

    Logger.info(
      "Update Dashboard #{inspect(org_id)} #{inspect(user_id)} #{inspect(id_or_name)} #{inspect(new_content)}"
    )

    with {:ok, dashboard} <- Store.get(org_id, id_or_name),
         {:ok, :valid} <- Utils.valid_widgets?(req.dashboard),
         {:ok, new} <- Store.update(org_id, dashboard, new_name, new_content),
         {:ok, nil} <- Event.publish("updated", dashboard.id, org_id) do
      %UpdateResponse{dashboard: encode(new)}
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

  def destroy(req, _call) do
    {org_id, user_id} = req |> extract_ids

    id_or_name = req.id_or_name

    Logger.info("Delete Dashboard #{inspect(org_id)} #{inspect(user_id)} #{inspect(id_or_name)}")

    with {:ok, dashboard} <- Store.get(org_id, id_or_name),
         {:ok, _} <- Store.delete(dashboard),
         {:ok, nil} <- Event.publish("deleted", dashboard.id, org_id) do
      %DestroyResponse{id: dashboard.id}
    else
      {:error, :not_found} ->
        raise GRPC.RPCError, status: :not_found, message: "Dashboard #{id_or_name} not found"

      {:error, :unknown, message} ->
        raise GRPC.RPCError, status: :unknown, message: message
    end
  end

  defp extract_ids(%{metadata: metadata}) do
    {metadata.org_id, metadata.user_id}
  end

  def encode(records) when is_list(records) do
    records
    |> Enum.map(fn record -> encode(record) end)
  end

  def encode(record) do
    record
    |> Utils.record_to_proto(InternalApi.Dashboardhub.Dashboard)
  end
end
