defmodule Front.RBAC.Role do
  @moduledoc """
  Data model for showing and modyfing RBAC roles
  """

  defmodule Permission do
    @moduledoc """
    Data model for showing and modyfing RBAC permissions within a role
    """
    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field(:id, :string)
      field(:name, :string)
      field(:description, :string)
      field(:granted, :boolean, default: false)
    end

    @fields ~w(id name description granted)a
    @required ~w(name granted)a
    @default_permissions ~w(organization.view project.view)

    def new(params) when is_struct(params), do: new(Map.from_struct(params))
    def new(params) when is_list(params), do: new(Map.new(params))
    def new(params) when is_map(params), do: struct(__MODULE__, params)

    def changeset(permission, params) do
      permission
      |> Ecto.Changeset.cast(params, @fields)
      |> Ecto.Changeset.validate_required(@required)
      |> grant_default_permissions()
    end

    def grant_default_permissions(changeset) do
      if Ecto.Changeset.get_field(changeset, :name) in @default_permissions,
        do: Ecto.Changeset.put_change(changeset, :granted, true),
        else: changeset
    end
  end

  use Ecto.Schema

  @primary_key {:id, :binary_id, default: "", autogenerate: false}
  embedded_schema do
    field(:name, :string, default: "")
    field(:description, :string, default: "")
    field(:scope, Ecto.Enum, values: [:organization, :project])

    field(:role_mapping, :boolean, default: false)
    field(:maps_to, Ecto.UUID)

    embeds_many(:permissions, Permission, on_replace: :delete)
  end

  @fields ~w(id name description scope role_mapping maps_to)a
  @required ~w(name scope role_mapping)a

  def new(params \\ []) do
    permissions =
      (params[:permissions] || [])
      |> Enum.map(&Permission.new/1)
      |> Enum.sort_by(& &1.name)

    params =
      params
      |> Enum.to_list()
      |> Keyword.put(:permissions, permissions)

    struct(__MODULE__, Enum.to_list(params))
  end

  def changeset(role, params, extra \\ []) do
    role
    |> Ecto.Changeset.cast(params, @fields)
    |> Ecto.Changeset.cast_embed(:permissions)
    |> Ecto.Changeset.validate_required(@required)
    |> Ecto.Changeset.validate_length(:name, max: 255)
    |> Ecto.Changeset.validate_exclusion(:name, extra[:used_names] || [],
      message: "has already been taken"
    )
  end

  def from_api(role, permissions) do
    new()
    |> changeset(
      role
      |> Map.take(~w(id name description)a)
      |> Map.merge(scope_from_api(role))
      |> Map.merge(maps_to_from_api(role))
      |> Map.put(:permissions, permissions_from_api(role, permissions))
    )
    |> Ecto.Changeset.apply_changes()
  end

  defp scope_from_api(%{scope: value}) when is_integer(value),
    do: scope_from_api(InternalApi.RBAC.Scope.key(value))

  defp scope_from_api(%{scope: value}) when is_atom(value),
    do: scope_from_api(value)

  defp scope_from_api(:SCOPE_ORG), do: %{scope: :organization}
  defp scope_from_api(:SCOPE_PROJECT), do: %{scope: :project}
  defp scope_from_api(_), do: %{}

  defp permissions_from_api(role, all_permissions) do
    permission_ids = role |> Map.get(:rbac_permissions, []) |> MapSet.new(& &1.id)
    granted? = fn permission -> permission.id in permission_ids end

    all_permissions
    |> Stream.map(&Map.take(&1, ~w(id name description)a))
    |> Stream.map(&Map.put(&1, :granted, granted?.(&1)))
    |> Enum.sort_by(& &1.name)
  end

  defp maps_to_from_api(%{maps_to: nil}),
    do: %{role_mapping: false, maps_to: nil}

  defp maps_to_from_api(%{maps_to: %{id: maps_to}}),
    do: %{role_mapping: true, maps_to: maps_to}

  def to_api(model = %__MODULE__{}, extra_params) do
    model
    |> Map.take(~w(id name description)a)
    |> Map.put(:scope, InternalApi.RBAC.Scope.value(scope_to_api(model)))
    |> Map.put(:maps_to, maps_to_to_api(model, extra_params))
    |> Map.put(:rbac_permissions, permissions_to_api(model, extra_params))
    |> Map.put(:org_id, extra_params[:org_id] || "")
    |> InternalApi.RBAC.Role.new()
  end

  defp scope_to_api(%__MODULE__{scope: :organization}), do: :SCOPE_ORG
  defp scope_to_api(%__MODULE__{scope: :project}), do: :SCOPE_PROJECT
  defp scope_to_api(%__MODULE__{}), do: :SCOPE_UNSPECIFIED

  defp maps_to_to_api(%__MODULE__{role_mapping: false}, _extra_params), do: nil
  defp maps_to_to_api(%__MODULE__{maps_to: nil}, _extra_params), do: nil

  defp maps_to_to_api(%__MODULE__{maps_to: maps_to}, extra_params) do
    Enum.find(extra_params[:roles], &(&1.id == maps_to))
  end

  defp permissions_to_api(%__MODULE__{permissions: permissions}, extra_params) do
    granted_permissions = permissions |> Enum.filter(& &1.granted) |> MapSet.new(& &1.name)
    extra_params[:permissions] |> Enum.filter(&(&1.name in granted_permissions))
  end
end
