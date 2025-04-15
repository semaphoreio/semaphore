defmodule PipelinesAPI.RBACClient.ResponseFormatter do
  @moduledoc """
  Module parses the response from Guard RBAC service and transforms it
  from protobuf messages into more suitable format for HTTP communication with
  API clients.
  """

  alias Util.ToTuple

  def process_list_user_permissions({:ok, %{permissions: permissions}}),
    do: ToTuple.ok(permissions)

  def process_list_user_permissions({:ok, _}),
    do: ToTuple.error({:internal_error, "internal error"})

  def process_list_user_permissions(error), do: error

  def process_list_project_members_response({:ok, %{members: members}}),
    do: ToTuple.ok(members)

  def process_list_project_members_response({:ok, _}),
    do: ToTuple.error({:internal_error, "internal error"})

  def process_list_project_members_response(error), do: error

  def process_list_roles_response({:ok, %{roles: roles}}, ""), do: ToTuple.ok(roles)

  def process_list_roles_response({:ok, %{roles: roles}}, scope),
    do: roles |> Enum.filter(fn role -> role.scope == scope end) |> ToTuple.ok()

  def process_list_roles_response({:ok, _}, _),
    do: ToTuple.error({:internal_error, "internal error"})

  def process_list_roles_response(error, _), do: error

  def process_retract_role_response({:ok, _response}), do: ToTuple.ok(true)

  def process_retract_role_response(error = {:error, _}), do: error
end
