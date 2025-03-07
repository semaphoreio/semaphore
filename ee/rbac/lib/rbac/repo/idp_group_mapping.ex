defmodule Rbac.Repo.IdpGroupMapping do
  use Rbac.Repo.Schema
  import Ecto.Changeset

  @timestamps_opts [type: :utc_datetime]

  @required_fields [
    :organization_id,
    :group_mappings
  ]

  @updatable_fields [
    :organization_id
  ]

  # Define embedded schema for a single group mapping
  defmodule GroupMapping do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field(:idp_group_id, :string)
      field(:semaphore_group_id, :binary_id)
    end

    def changeset(group_mapping, params) do
      group_mapping
      |> cast(params, [:idp_group_id, :semaphore_group_id])
      |> validate_required([:idp_group_id, :semaphore_group_id])
    end
  end

  schema "idp_group_mapping" do
    field(:organization_id, :binary_id)
    embeds_many(:group_mappings, GroupMapping, on_replace: :delete)

    timestamps()
  end

  def changeset(idp_group_mapping, params \\ %{}) do
    idp_group_mapping
    |> cast(params, @updatable_fields)
    |> cast_embed(:group_mappings, with: &GroupMapping.changeset/2)
    |> validate_required(@required_fields)
    |> unique_constraint(:organization_id,
      name: "idp_group_mapping_organization_id_index",
      message: "Organization already has IDP group mappings"
    )
    |> validate_group_mapping_uniqueness()
  end

  # Validate that there are no duplicate idp_group_id values
  defp validate_group_mapping_uniqueness(changeset) do
    case get_change(changeset, :group_mappings) do
      nil ->
        changeset

      mappings ->
        # Extract idp_group_id values safely
        idp_group_ids =
          Enum.map(mappings, fn mapping ->
            cond do
              # For Ecto.Changeset instances
              is_map(mapping.changes) && Map.has_key?(mapping.changes, :idp_group_id) ->
                mapping.changes.idp_group_id

              true ->
                nil
            end
          end)
          |> Enum.reject(&is_nil/1)

        unique_ids = Enum.uniq(idp_group_ids)

        if length(idp_group_ids) != length(unique_ids) do
          add_error(changeset, :group_mappings, "contains duplicate IDP group IDs")
        else
          changeset
        end
    end
  end

  def insert_or_update(fields \\ []) do
    # Check if there's an existing record for this organization
    case fetch_for_org(Keyword.get(fields, :organization_id)) do
      {:ok, existing} ->
        # Update existing record
        existing
        |> changeset(Map.new(fields))
        |> Rbac.Repo.update()

      {:error, :not_found} ->
        # Create new record
        %__MODULE__{}
        |> changeset(Map.new(fields))
        |> Rbac.Repo.insert()

      error ->
        error
    end
  end

  def fetch_for_org(organization_id) do
    import Ecto.Query, only: [where: 3]

    res = __MODULE__ |> where([m], m.organization_id == ^organization_id) |> Rbac.Repo.one()

    case res do
      nil -> {:error, :not_found}
      mapping -> {:ok, mapping}
    end
  end

  # Extract a list of all mappings for easier consumption
  def to_list(mapping) do
    Enum.map(mapping.group_mappings, fn m ->
      %{idp_group_id: m.idp_group_id, semaphore_group_id: m.semaphore_group_id}
    end)
  end
end
