defmodule Front.Models.ServiceAccount do
  @moduledoc """
  Model representing a Service Account
  """

  alias Front.RBAC.Members
  alias Front.RBAC.RoleManagement
  require Logger

  @type role_source :: :unspecified | :manual | :external

  @type role :: %{
          id: String.t(),
          name: String.t(),
          source: role_source()
        }

  @type person :: %{
          id: String.t(),
          name: String.t()
        }

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          org_id: String.t(),
          creator_id: String.t(),
          owner_id: String.t(),
          owner_active: boolean(),
          creator: person() | nil,
          owner: person() | nil,
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          deactivated: boolean(),
          roles: [role()]
        }

  defstruct [
    :id,
    :name,
    :description,
    :org_id,
    :creator_id,
    :owner_id,
    :owner_active,
    :creator,
    :owner,
    :created_at,
    :updated_at,
    :deactivated,
    roles: []
  ]

  def list(org_id, page) do
    # rbac accepts page_no starting from 0 :<
    page_no = page - 1
    page_size = 20

    with {:ok, {members, total_pages}} <-
           Members.list_org_members(org_id,
             page_no: page_no,
             page_size: page_size,
             member_type: "service_account"
           ),
         member_ids <- Enum.map(members, & &1.id),
         {:ok, service_accounts} <-
           Front.ServiceAccount.describe_many(member_ids, org_id),
         service_accounts <-
           assign_service_accounts_to_members(members, service_accounts),
         service_accounts <- assign_people(service_accounts) do
      {:ok, {service_accounts, total_pages}}
    else
      error ->
        Logger.error("Failed to list service accounts: #{inspect(error)}")
        {:error, "Failed to list service accounts"}
    end
  end

  def create(org_id, name, description, user_id, role_id) do
    with {:ok, {service_account, token}} <-
           Front.ServiceAccount.create(org_id, name, description, user_id),
         {:ok, _} <- assign_role(org_id, user_id, service_account, role_id) do
      {:ok, {from_proto(service_account), token}}
    else
      error ->
        Logger.error("Failed to create service account or assign role: #{inspect(error)}")
        {:error, "Failed to create service account or assign role"}
    end
  end

  def update(service_account_id, org_id, name, description, user_id, role_id) do
    with {:ok, service_account} <-
           Front.ServiceAccount.update(service_account_id, org_id, name, description),
         {:ok, _} <-
           assign_role(
             service_account.org_id,
             user_id,
             service_account,
             role_id
           ) do
      {:ok, from_proto(service_account)}
    else
      error ->
        Logger.error("Failed to update service account or assign role: #{inspect(error)}")
        {:error, "Failed to update service account or assign role"}
    end
  end

  def delete(service_account_id, org_id) do
    with {:ok, service_account} <- Front.ServiceAccount.describe(service_account_id, org_id),
         :ok <- Front.ServiceAccount.delete(service_account_id, org_id) do
      {:ok, from_proto(service_account)}
    else
      error ->
        Logger.error("Failed to delete service account: #{inspect(error)}")
        {:error, "Failed to delete service account"}
    end
  end

  @doc """
  Makes the given user the owner of a service account.

  The caller passes their own id: an account acts for the person who took it on, and
  lending someone else's access is theirs to do, not an administrator's.
  """
  def take_ownership(service_account_id, org_id, user_id) do
    case Front.ServiceAccount.set_owner(service_account_id, org_id, user_id) do
      {:ok, service_account} ->
        {:ok, from_proto(service_account)}

      {:error, message} when is_binary(message) ->
        {:error, message}

      error ->
        Logger.error("Failed to take ownership of service account: #{inspect(error)}")
        {:error, "Failed to take ownership of the service account"}
    end
  end

  @doc """
  Gives up ownership of a service account on behalf of the user making the request.

  Guard accepts this only from the current owner, since it is their own access the
  account was using.
  """
  def release_ownership(service_account_id, org_id, user_id) do
    case Front.ServiceAccount.release_owner(service_account_id, org_id, user_id) do
      {:ok, service_account} ->
        {:ok, from_proto(service_account)}

      {:error, message} when is_binary(message) ->
        {:error, message}

      error ->
        Logger.error("Failed to release service account: #{inspect(error)}")
        {:error, "Failed to give up ownership of the service account"}
    end
  end

  def regenerate_token(service_account_id, org_id, requester_id) do
    with {:ok, service_account} <- Front.ServiceAccount.describe(service_account_id, org_id),
         {:ok, api_token} <-
           Front.ServiceAccount.regenerate_token(service_account_id, org_id, requester_id) do
      {:ok, {from_proto(service_account), api_token}}
    else
      error ->
        Logger.error("Failed to regenerate service account token: #{inspect(error)}")
        {:error, "Failed to regenerate service account token"}
    end
  end

  @doc """
  Creates a new ServiceAccount struct from protobuf data
  """
  @spec from_proto(InternalApi.ServiceAccount.t()) :: t
  def from_proto(proto) do
    %__MODULE__{
      id: proto.id,
      name: proto.name,
      description: proto.description,
      org_id: proto.org_id,
      creator_id: proto.creator_id,
      owner_id: proto.owner_id,
      owner_active: proto.owner_active,
      created_at: timestamp_to_datetime(proto.created_at),
      updated_at: timestamp_to_datetime(proto.updated_at),
      deactivated: proto.deactivated,
      roles: []
    }
  end

  defp timestamp_to_datetime(%Google.Protobuf.Timestamp{seconds: seconds}) do
    DateTime.from_unix!(seconds)
  end

  defp timestamp_to_datetime(_), do: DateTime.utc_now()

  # The owner and the creator are shown by name: the owner because it is whose access the
  # account uses, the creator because they are who to ask when an account has no owner.
  defp assign_people(service_accounts) do
    people =
      service_accounts
      |> Enum.flat_map(&[&1.owner_id, &1.creator_id])
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.uniq()
      |> fetch_people()

    Enum.map(service_accounts, fn service_account ->
      %{
        service_account
        | owner: Map.get(people, service_account.owner_id),
          creator: Map.get(people, service_account.creator_id)
      }
    end)
  end

  defp fetch_people([]), do: %{}

  defp fetch_people(ids) do
    ids
    |> Front.Models.User.find_many()
    |> Map.new(&{&1.id, %{id: &1.id, name: &1.name}})
  rescue
    error ->
      Logger.error("Failed to look up service account owners: #{inspect(error)}")
      %{}
  end

  defp assign_service_accounts_to_members(members, service_accounts) do
    members
    |> Enum.map(fn member ->
      {member, Enum.find(service_accounts, &(&1.id == member.id))}
    end)
    |> Enum.map(fn
      {member, nil} ->
        Logger.warn("Service account #{member.id} not found in service accounts list")
        nil

      {member, service_account} ->
        from_proto(service_account)
        |> Map.put(:roles, parse_role_bindings(member.subject_role_bindings))
    end)
    |> Enum.filter(& &1)
  end

  @spec parse_role_bindings([InternalApi.RBAC.SubjectRoleBinding.t()]) :: [role]
  defp parse_role_bindings(role_bindings) do
    Enum.map(role_bindings, &parse_role_binding/1)
  end

  @spec parse_role_binding(InternalApi.RBAC.SubjectRoleBinding.t()) :: role()
  defp parse_role_binding(subject_role_binding) do
    %{
      id: subject_role_binding.role.id,
      source: parse_role_source(subject_role_binding.source),
      name: subject_role_binding.role.name
    }
  end

  @spec parse_role_source(InternalApi.RBAC.RoleBindingSource.t()) :: role_source
  defp parse_role_source(subject_role_source) do
    subject_role_source
    |> InternalApi.RBAC.RoleBindingSource.key()
    |> case do
      :ROLE_BINDING_SOURCE_MANUALLY ->
        :manual

      source
      when source in [
             :ROLE_BINDING_SOURCE_GITHUB,
             :ROLE_BINDING_SOURCE_BITBUCKET,
             :ROLE_BINDING_SOURCE_GITLAB,
             :ROLE_BINDING_SOURCE_SCIM,
             :ROLE_BINDING_SOURCE_INHERITED_FROM_ORG_ROLE,
             :ROLE_BINDING_SOURCE_SAML_JIT
           ] ->
        :external

      _ ->
        :unspecified
    end
  end

  defp assign_role(org_id, user_id, service_account, role_id) do
    RoleManagement.assign_role(
      user_id,
      org_id,
      service_account.id,
      role_id,
      "",
      "service_account"
    )
  end
end
