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

  def process_list_members_response({:ok, %{members: members, total_pages: total_pages}}) do
    ToTuple.ok(%{members: serialize_members(members), total_pages: total_pages})
  end

  def process_list_members_response({:ok, _}),
    do: ToTuple.error({:internal_error, "internal error"})

  def process_list_members_response(error), do: error

  def process_describe_role_response({:ok, %{role: role}}), do: ToTuple.ok(serialize_role(role))

  def process_describe_role_response({:ok, _}),
    do: ToTuple.error({:internal_error, "internal error"})

  def process_describe_role_response(error), do: error

  def process_modify_role_response(result), do: process_describe_role_response(result)

  def process_destroy_role_response({:ok, _response}), do: ToTuple.ok(%{status: "deleted"})
  def process_destroy_role_response(error = {:error, _}), do: error

  def process_assign_role_response({:ok, _response}), do: ToTuple.ok(%{status: "assigned"})
  def process_assign_role_response(error = {:error, _}), do: error

  def process_list_existing_permissions_response({:ok, %{permissions: permissions}}) do
    serialized =
      Enum.map(permissions, fn p ->
        %{id: p.id, name: p.name, description: p.description}
      end)

    ToTuple.ok(%{permissions: serialized})
  end

  def process_list_existing_permissions_response({:ok, _}),
    do: ToTuple.error({:internal_error, "internal error"})

  def process_list_existing_permissions_response(error), do: error

  defp serialize_role(role) do
    %{
      id: role.id,
      name: role.name,
      org_id: role.org_id,
      scope: scope_to_string(role.scope),
      description: role.description,
      permissions: Enum.map(role.rbac_permissions, fn p -> p.name end),
      readonly: role.readonly
    }
  end

  def serialize_members(members) do
    Enum.map(members, fn m ->
      %{
        id: m.subject.subject_id,
        subject_type: subject_type_to_string(m.subject.subject_type),
        name: m.subject.display_name,
        roles:
          Enum.map(m.subject_role_bindings, fn rb ->
            %{
              role_id: rb.role.id,
              role_name: rb.role.name,
              source: source_to_string(rb.source)
            }
          end)
      }
    end)
  end

  defp subject_type_to_string(0), do: "user"
  defp subject_type_to_string(1), do: "group"
  defp subject_type_to_string(2), do: "service_account"
  defp subject_type_to_string(_), do: "unknown"

  defp source_to_string(0), do: "unspecified"
  defp source_to_string(1), do: "manually"
  defp source_to_string(2), do: "github"
  defp source_to_string(3), do: "bitbucket"
  defp source_to_string(4), do: "gitlab"
  defp source_to_string(5), do: "scim"
  defp source_to_string(6), do: "inherited_from_org_role"
  defp source_to_string(7), do: "saml_jit"
  defp source_to_string(_), do: "unknown"

  defp scope_to_string(0), do: "unspecified"
  defp scope_to_string(1), do: "org"
  defp scope_to_string(2), do: "project"
  defp scope_to_string(_), do: "unknown"
end
