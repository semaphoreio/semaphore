defmodule Rbac.Okta.IdpGroupMappings do
  @moduledoc """
  This module handles operations related to IDP group mappings.
  It provides functionality to create, update, and retrieve group mappings.
  """

  require Ecto.Query
  alias Ecto.Query
  alias Rbac.Repo
  alias Rbac.Repo.IdpGroupMapping

  @doc """
  Creates or updates group mappings for an organization.

  ## Parameters
    * organization_id - The ID of the organization
    * group_mappings - A list of maps with idp_group_id and semaphore_group_id keys
    
  ## Returns
    * `{:ok, mapping}` - The created or updated mapping
    * `{:error, changeset}` - Error with changeset containing validation errors
  """
  def create_or_update(organization_id, group_mappings) when is_list(group_mappings) do
    IdpGroupMapping.insert_or_update(
      organization_id: organization_id,
      group_mappings: group_mappings
    )
  end

  @doc """
  Retrieves group mappings for an organization.

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
    * `{:ok, semaphore_groups}` - List of mapped Semaphore group IDs
    * `{:error, :not_found}` - No mapping found for the organization
  """
  def map_groups(organization_id, idp_groups) when is_list(idp_groups) do
    case get_for_organization(organization_id) do
      {:ok, mapping} ->
        # Create a lookup map for faster search
        lookup_map =
          Enum.reduce(mapping.group_mappings, %{}, fn m, acc ->
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

        {:ok, mapped_groups}

      error ->
        error
    end
  end

  @doc """
  Gets a list of all mappings.

  ## Parameters
    * organization_id - The ID of the organization

  ## Returns
    * `{:ok, [%{idp_group_id: string, semaphore_group_id: string}]}` - List of all mappings
    * `{:error, :not_found}` - No mapping found for the organization
  """
  def list_mappings(organization_id) do
    case IdpGroupMapping.fetch_for_org(organization_id) do
      {:ok, mapping} ->
        {:ok, IdpGroupMapping.to_list(mapping)}

      error ->
        error
    end
  end
end
