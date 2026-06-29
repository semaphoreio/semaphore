defmodule PipelinesAPI.Roles.PermissionResolver do
  @moduledoc """
  Resolves permission names to InternalApi.RBAC.Permission structs with their
  ids populated.

  rbac's ModifyRole keys role permissions by id, but the public API accepts
  permission names — the stable, environment-portable identifier (permission ids
  are generated per environment). We look the ids up per scope here so callers
  can keep using names.
  """
  alias PipelinesAPI.RBACClient
  alias PipelinesAPI.Util.ToTuple
  alias InternalApi.RBAC

  @spec resolve(integer(), [String.t()]) :: {:ok, [RBAC.Permission.t()]} | {:error, term()}
  def resolve(_scope, []), do: ToTuple.ok([])

  def resolve(scope, names) do
    case RBACClient.list_existing_permissions(%{scope: scope}) do
      {:ok, %{permissions: permissions}} ->
        ids_by_name = Map.new(permissions, &{&1.name, &1.id})

        case Enum.reject(names, &Map.has_key?(ids_by_name, &1)) do
          [] ->
            resolved =
              Enum.map(names, fn name ->
                RBAC.Permission.new(id: ids_by_name[name], name: name)
              end)

            ToTuple.ok(resolved)

          unknown ->
            ToTuple.user_error("unknown permission(s): #{Enum.join(unknown, ", ")}")
        end

      error ->
        error
    end
  end
end
