defmodule Rbac.Repo.IdpGroupMapping do
  use Rbac.Repo.Schema
  import Ecto.Changeset

  @timestamps_opts [type: :utc_datetime]

  @required_fields [
    :organization_id,
    :group_mapping,
    :role_mapping,
    :default_role_id
  ]

  @updatable_fields [
    :organization_id,
    :default_role_id
  ]

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

  defmodule RoleMapping do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field(:idp_role_id, :string)
      field(:semaphore_role_id, :binary_id)
    end

    def changeset(role_mapping, params) do
      role_mapping
      |> cast(params, [:idp_role_id, :semaphore_role_id])
      |> validate_required([:idp_role_id, :semaphore_role_id])
    end
  end

  schema "idp_group_mapping" do
    field(:organization_id, :binary_id)
    embeds_many(:group_mapping, GroupMapping, on_replace: :delete)
    embeds_many(:role_mapping, RoleMapping, on_replace: :delete)
    field(:default_role_id, :binary_id)

    timestamps()
  end

  def changeset(idp_group_mapping, params \\ %{}) do
    idp_group_mapping
    |> cast(params, @updatable_fields)
    |> cast_embed(:group_mapping, with: &GroupMapping.changeset/2, required: true)
    |> cast_embed(:role_mapping, with: &RoleMapping.changeset/2, required: false)
    |> validate_required(@required_fields)
    |> unique_constraint(:organization_id,
      name: "idp_group_mapping_organization_id_index",
      message: "Organization already has IDP group mappings"
    )
    |> validate_group_mapping_uniqueness()
    |> validate_group_mapping_not_empty()
    |> validate_role_mapping_uniqueness()
  end

  defp validate_group_mapping_uniqueness(changeset) do
    case get_change(changeset, :group_mapping) do
      nil ->
        changeset

      mappings ->
        idp_group_ids =
          Enum.map(mappings, fn mapping ->
            if is_map(mapping.changes) && Map.has_key?(mapping.changes, :idp_group_id),
              do: mapping.changes.idp_group_id,
              else: nil
          end)
          |> Enum.reject(&is_nil/1)

        unique_ids = Enum.uniq(idp_group_ids)

        if length(idp_group_ids) != length(unique_ids) do
          add_error(changeset, :group_mapping, "contains duplicate IDP group IDs")
        else
          changeset
        end
    end
  end

  defp validate_role_mapping_uniqueness(changeset) do
    case get_change(changeset, :role_mapping) do
      nil ->
        changeset

      [] ->
        changeset

      mappings ->
        idp_role_ids =
          Enum.map(mappings, fn mapping ->
            if is_map(mapping.changes) && Map.has_key?(mapping.changes, :idp_role_id),
              do: mapping.changes.idp_role_id,
              else: nil
          end)
          |> Enum.reject(&is_nil/1)

        unique_ids = Enum.uniq(idp_role_ids)

        if length(idp_role_ids) != length(unique_ids) do
          add_error(changeset, :role_mapping, "contains duplicate IDP role IDs")
        else
          changeset
        end
    end
  end

  defp validate_group_mapping_not_empty(changeset) do
    case get_change(changeset, :group_mapping) do
      nil ->
        case get_field(changeset, :group_mapping) do
          nil -> add_error(changeset, :group_mapping, "must be provided")
          [] -> add_error(changeset, :group_mapping, "cannot be empty")
          _ -> changeset
        end

      [] ->
        add_error(changeset, :group_mapping, "cannot be empty")

      _ ->
        changeset
    end
  end

  def insert_or_update(fields \\ []) do
    case fetch_for_org(Keyword.get(fields, :organization_id)) do
      {:ok, existing} ->
        existing
        |> changeset(Map.new(fields))
        |> Rbac.Repo.update()

      {:error, :not_found} ->
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
end
