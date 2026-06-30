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
      {:ok, result} -> map_grpc_status(result)
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
      {:ok, result} -> map_grpc_status(result)
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
      {:ok, result} -> map_grpc_status(result)
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
      {:ok, result} -> map_grpc_status(result)
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

  # List Org Members

  def list_org_members({:ok, request = %{org_id: _}}) do
    result =
      Wormhole.capture(__MODULE__, :list_members_, [request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout
      )

    case result do
      {:ok, result} -> map_grpc_status(result)
      {:error, reason} -> Log.internal_error(reason, "list_org_members")
    end
  end

  def list_org_members({:ok, _}), do: ToTuple.user_error("invalid list org members request")
  def list_org_members(error), do: error

  # Describe Role

  def describe_role({:ok, request = %{role_id: _, org_id: _}}) do
    result =
      Wormhole.capture(__MODULE__, :describe_role_, [request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout
      )

    case result do
      {:ok, result} -> map_grpc_status(result)
      {:error, reason} -> Log.internal_error(reason, "describe_role")
    end
  end

  def describe_role({:ok, _}), do: ToTuple.user_error("invalid describe role request")
  def describe_role(error), do: error

  def describe_role_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.RBAC_client", ["describe_role_"], fn ->
      channel
      |> RBAC.Stub.describe_role(request, opts())
    end)
  end

  # Modify Role

  def modify_role({:ok, request = %{role: _}}) do
    result =
      Wormhole.capture(__MODULE__, :modify_role_, [request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout
      )

    case result do
      {:ok, result} -> map_grpc_status(result)
      {:error, reason} -> Log.internal_error(reason, "modify_role")
    end
  end

  def modify_role({:ok, _}), do: ToTuple.user_error("invalid modify role request")
  def modify_role(error), do: error

  def modify_role_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.RBAC_client", ["modify_role_"], fn ->
      channel
      |> RBAC.Stub.modify_role(request, opts())
    end)
  end

  # Destroy Role

  def destroy_role({:ok, request = %{role_id: _, org_id: _}}) do
    result =
      Wormhole.capture(__MODULE__, :destroy_role_, [request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout
      )

    case result do
      {:ok, result} -> map_grpc_status(result)
      {:error, reason} -> Log.internal_error(reason, "destroy_role")
    end
  end

  def destroy_role({:ok, _}), do: ToTuple.user_error("invalid destroy role request")
  def destroy_role(error), do: error

  def destroy_role_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.RBAC_client", ["destroy_role_"], fn ->
      channel
      |> RBAC.Stub.destroy_role(request, opts())
    end)
  end

  # Assign Role

  def assign_role({:ok, request = %{role_assignment: _, requester_id: _}}) do
    result =
      Wormhole.capture(__MODULE__, :assign_role_, [request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout
      )

    case result do
      {:ok, result} -> map_grpc_status(result)
      {:error, reason} -> Log.internal_error(reason, "assign_role")
    end
  end

  def assign_role({:ok, _}), do: ToTuple.user_error("invalid assign role request")
  def assign_role(error), do: error

  def assign_role_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.RBAC_client", ["assign_role_"], fn ->
      channel
      |> RBAC.Stub.assign_role(request, opts())
    end)
  end

  # List Existing Permissions

  def list_existing_permissions({:ok, request = %{scope: _}}) do
    result =
      Wormhole.capture(__MODULE__, :list_existing_permissions_, [request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout
      )

    case result do
      {:ok, result} -> map_grpc_status(result)
      {:error, reason} -> Log.internal_error(reason, "list_existing_permissions")
    end
  end

  def list_existing_permissions({:ok, _}),
    do: ToTuple.user_error("invalid list existing permissions request")

  def list_existing_permissions(error), do: error

  def list_existing_permissions_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.RBAC_client", ["list_existing_permissions_"], fn ->
      channel
      |> RBAC.Stub.list_existing_permissions(request, opts())
    end)
  end

  # Maps a gRPC reply to the result shape the response formatters expect: success
  # passes through; NOT_FOUND -> not_found (404); INVALID_ARGUMENT / FAILED_PRECONDITION /
  # ALREADY_EXISTS -> user error (4xx); anything else -> internal (500). Without this a
  # clean backend NOT_FOUND surfaced as a 500.
  defp map_grpc_status({:ok, response}), do: {:ok, response}

  defp map_grpc_status({:error, %GRPC.RPCError{message: message, status: status}}) do
    cond do
      status in [3, 6, 9] -> ToTuple.user_error(message)
      status == 5 -> ToTuple.not_found_error(message)
      status == 7 -> ToTuple.forbidden_error(message)
      true -> Log.internal_error(message, "rbac")
    end
  end

  defp map_grpc_status(other), do: Log.internal_error(other, "rbac")
end
