defmodule PipelinesAPI.RBACClient.GrpcClient do
  @moduledoc """
  Module is used for making gRPC calls to Guard RBAC service.
  """

  alias InternalApi.RBAC.RBAC
  alias PipelinesAPI.Util.{Log, Metrics, ToTuple}

  require Logger

  defp url(), do: System.get_env("INTERNAL_API_URL_RBAC")

  @wormhole_timeout Application.compile_env(:pipelines_api, :wormhole_timeout, [])
  @grpc_timeout Application.compile_env(:pipelines_api, :grpc_timeout, [])
  defp opts(), do: [{:timeout, @grpc_timeout}]

  # List User Permissions

  def list_user_permissions({:ok, request = %{org_id: _, user_id: _, project_id: _}}) do
    LogTee.debug(request, "RBACClient.GrpcClient.list_user_permissions")

    result =
      Wormhole.capture(__MODULE__, :list_user_permissions_, [request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout
      )

    LogTee.debug(result, "RBACClient.GrpcClient.list_user_permissions result")

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "list_user_permissions")
    end
  end

  def list_user_permissions({:ok, _}),
    do: ToTuple.user_error("invalid request for list_user_permissions")

  def list_user_permissions(error), do: error

  def list_user_permissions_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.RBAC_client", ["list_user_permissions_"], fn ->
      channel
      |> RBAC.Stub.list_user_permissions(request, opts())
    end)
  end

  # List Project Members

  def list_project_members({:ok, list_project_members_request = %{org_id: _, project_id: _}}) do
    LogTee.debug(list_project_members_request, "RBACClient.GrpcClient.list_project_members")

    result =
      Wormhole.capture(__MODULE__, :list_members_, [list_project_members_request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout
      )

    LogTee.debug(result, "RBACClient.GrpcClient.list_project_members result")

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "list_project_members")
    end
  end

  def list_project_members({:ok, _}),
    do: ToTuple.user_error("invalid list project members request")

  def list_project_members(error), do: error

  def list_members_(list_members_request) do
    LogTee.debug(list_members_request, "RBACClient.GrpcClient.list_members_ connecting")
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.RBAC_client", ["list_members_"], fn ->
      LogTee.debug(
        list_members_request,
        "RBACClient.GrpcClient.list_members_ making grpc call"
      )

      channel
      |> RBAC.Stub.list_members(list_members_request, opts())
    end)
  end

  def list_roles({:ok, list_roles_request = %{org_id: _}}) do
    result =
      Wormhole.capture(__MODULE__, :list_roles_, [list_roles_request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "list_roles")
    end
  end

  def list_roles({:ok, _}), do: ToTuple.user_error("invalid list roles request")

  def list_roles(error), do: error

  def list_roles_(list_roles_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.RBAC_client", ["list_roles_"], fn ->
      channel
      |> RBAC.Stub.list_roles(list_roles_request, opts())
    end)
  end

  def retract_role({:ok, retract_role_request = %{role_assignment: _, requester_id: _}}) do
    LogTee.debug(retract_role_request, "RBACClient.GrpcClient.retract_role")

    result =
      Wormhole.capture(__MODULE__, :retract_role_, [retract_role_request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "retract_role")
    end
  end

  def retract_role({:ok, _}), do: ToTuple.user_error("invalid retract role request")

  def retract_role(error), do: error

  def retract_role_(retract_role_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.RBAC_client", ["retract_role_"], fn ->
      channel
      |> RBAC.Stub.retract_role(retract_role_request, opts())
    end)
  end
end
