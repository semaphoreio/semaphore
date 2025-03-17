defmodule Rbac.Okta.IdpGroupMapping do
  @moduledoc """
  This module handles operations related to IDP group mappings.
  It provides functionality to create, update, and retrieve group mappings.
  """

  alias Rbac.Repo.IdpGroupMapping

  @doc """
  Creates or updates mappings for an organization.

  ## Parameters
    * organization_id - The ID of the organization
    * group_mappings - A list of maps with idp_group_id and semaphore_group_id keys
    * role_mappings - A list of maps with idp_role_id and semaphore_role_id keys
    * default_role_id - The default role ID to use when no mappings match

  ## Returns
    * `{:ok, mapping}` - The created or updated mapping
    * `{:error, changeset}` - Error with changeset containing validation errors
  """
  def create_or_update(organization_id, group_mapping, role_mapping, default_role_id)
      when is_list(group_mapping) and is_list(role_mapping) do
    require Logger

    Logger.info(
      "req: group_mapping: #{inspect(group_mapping)}, role_mapping: #{inspect(role_mapping)}"
    )

    IdpGroupMapping.insert_or_update(
      organization_id: organization_id,
      group_mapping: group_mapping,
      role_mapping: role_mapping,
      default_role_id: default_role_id
    )
  end

  @doc """
  Retrieves mappings for an organization.

  ## Parameters
    * organization_id - The ID of the organization

  ## Returns
    * `{:ok, mapping}` - The mapping for the organization
    * `{:error, :not_found}` - No mapping found for the organization
    * `{:error, error}` - Other error that occurred
  """
  def get_for_organization(organization_id) do
    IdpGroupMapping.fetch_for_org(organization_id)
  end

  @doc """
  Maps IDP groups to Semaphore groups.

  ## Parameters
    * organization_id - The ID of the organization
    * idp_groups - List of IDP group identifiers

  ## Returns
    * `{:ok, semaphore_groups, default_role_id}` - List of mapped Semaphore group IDs and default role ID
    * `{:error, :not_found}` - No mapping found for the organization
  """
  def map_groups(organization_id, idp_groups) when is_list(idp_groups) do
    case get_for_organization(organization_id) do
      {:ok, mapping} ->
        # Create a lookup map for faster search
        lookup_map =
          Enum.reduce(mapping.group_mapping, %{}, fn m, acc ->
            Map.put(acc, m.idp_group_id, m.semaphore_group_id)
          end)

        # Find matching semaphore groups
        mapped_groups =
          idp_groups
          |> Enum.reduce([], fn idp_group, acc ->
            case Map.get(lookup_map, idp_group) do
              nil -> acc
              semaphore_group -> [semaphore_group | acc]
            end
          end)
          |> Enum.uniq()

        {:ok, mapped_groups, mapping.default_role_id}

      error ->
        error
    end
  end

  @doc """
  Maps IDP roles to Semaphore roles.

  ## Parameters
    * organization_id - The ID of the organization
    * idp_roles - List of IDP role identifiers

  ## Returns
    * `{:ok, semaphore_roles}` - List of mapped Semaphore role IDs
    * `{:error, :not_found}` - No mapping found for the organization
  """
  def map_roles(organization_id, idp_roles) when is_list(idp_roles) do
    case get_for_organization(organization_id) do
      {:ok, mapping} ->
        # Create a lookup map for faster search
        lookup_map =
          Enum.reduce(mapping.role_mapping || [], %{}, fn m, acc ->
            Map.put(acc, m.idp_role_id, m.semaphore_role_id)
          end)

        # Find matching semaphore roles
        mapped_roles =
          idp_roles
          |> Enum.reduce([], fn idp_role, acc ->
            case Map.get(lookup_map, idp_role) do
              nil -> acc
              semaphore_role -> [semaphore_role | acc]
            end
          end)
          |> Enum.uniq()

        {:ok, mapped_roles}

      error ->
        error
    end
  end
end
