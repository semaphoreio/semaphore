defmodule Rbac.Utils.Grpc do
  require Logger
  alias Rbac.Utils.Common

  def grpc_error!(type, message \\ "") when is_atom(type),
    do: raise(GRPC.RPCError, message: message, status: apply(GRPC.Status, type, []))

  def validate_uuid!(values) when is_list(values), do: Enum.each(values, &validate_uuid!(&1))

  def validate_uuid!(value) do
    if !Common.valid_uuid?(value) do
      Logger.error("Invalid uuid #{inspect(value)}")

      grpc_error!(
        :invalid_argument,
        "Invalid uuid passed as an argument where uuid v4 was expected."
      )
    end
  end

  def authorize!(permission, user_id, org_id, project_id \\ "") do
    alias Rbac.RoleBindingIdentification, as: RBI

    {:ok, rbi} = RBI.new(user_id: user_id, org_id: org_id, project_id: project_id)
    users_permisions = Rbac.Store.UserPermissions.read_user_permissions(rbi)

    if !(users_permisions =~ permission) do
      Logger.error("Missing permision #{inspect(permission)} for rbi #{inspect(rbi)}")
      grpc_error!(:permission_denied, "User unauthorized")
    end
  end
end
