defmodule Front.Models.DeploymentTarget do
  @moduledoc """
    Data model for modifying deployment targets
  """

  defmodule EnvVar do
    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field(:id, :string, default: "")
      field(:name, :string, default: "")
      field(:value, :string, default: "")
      field(:md5, :string, default: "")
    end

    def changeset(env_var, params) do
      env_var
      |> Ecto.Changeset.cast(params, ~w(id name value md5)a)
      |> Ecto.Changeset.validate_required([:name])
      |> validate_value_or_md5()
    end

    defp validate_value_or_md5(changeset) do
      md5 = Ecto.Changeset.get_field(changeset, :md5)

      if md5 && String.length(md5) > 0,
        do: Ecto.Changeset.validate_required(changeset, [:id]),
        else: Ecto.Changeset.validate_required(changeset, [:value])
    end
  end

  defmodule File do
    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field(:id, :string, default: "")
      field(:path, :string, default: "")
      field(:content, :string, default: "")
      field(:md5, :string, default: "")
    end

    def changeset(file, params) do
      file
      |> Ecto.Changeset.cast(params, ~w(id path content md5)a)
      |> Ecto.Changeset.validate_required([:path])
      |> validate_content_or_md5()
    end

    defp validate_content_or_md5(changeset) do
      md5 = Ecto.Changeset.get_field(changeset, :md5)

      if md5 && String.length(md5) > 0,
        do: Ecto.Changeset.validate_required(changeset, [:id]),
        else: Ecto.Changeset.validate_required(changeset, [:content])
    end
  end

  defmodule ObjectItem do
    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field(:match_mode, :integer)
      field(:pattern, :string)
    end

    @regex_match_mode 2
    @match_modes 1..2

    def changeset(object, params) do
      object
      |> Ecto.Changeset.cast(params, ~w(match_mode pattern)a)
      |> Ecto.Changeset.validate_required([:match_mode, :pattern])
      |> Ecto.Changeset.validate_inclusion(:match_mode, @match_modes)
      |> validate_pattern()
    end

    defp validate_pattern(changeset) do
      if @regex_match_mode == Ecto.Changeset.get_field(changeset, :match_mode),
        do: Ecto.Changeset.validate_change(changeset, :pattern, &validate_regex/2),
        else: changeset
    end

    defp validate_regex(:pattern, pattern) do
      case Regex.compile(pattern) do
        {:ok, _regex} -> []
        {:error, _reason} -> [pattern: "must be regex"]
      end
    end
  end

  use Ecto.Schema
  @primary_key {:id, :binary_id, default: "", autogenerate: false}
  embedded_schema do
    field(:name, :string)
    field(:description, :string, default: "")
    field(:url, :string, default: "")

    field(:bookmark_parameter1, :string, default: "")
    field(:bookmark_parameter2, :string, default: "")
    field(:bookmark_parameter3, :string, default: "")

    field(:unique_token, :string, default: "")

    embeds_many(:env_vars, EnvVar, on_replace: :delete)
    embeds_many(:files, File, on_replace: :delete)

    field(:roles, {:array, :string}, default: [])
    field(:members, {:array, :string}, default: [])
    field(:user_access, :string, default: "any")
    field(:auto_promotions, :boolean, default: true)

    field(:branch_mode, :string)
    field(:tag_mode, :string)
    field(:pr_mode, :string)

    embeds_many(:branches, ObjectItem, on_replace: :delete)
    embeds_many(:tags, ObjectItem, on_replace: :delete)
  end

  @fields ~w(id name description url unique_token
    bookmark_parameter1 bookmark_parameter2 bookmark_parameter3
    user_access roles members auto_promotions
    branch_mode tag_mode pr_mode)a
  @required ~w(name unique_token
    user_access auto_promotions
    branch_mode tag_mode pr_mode)a
  @plain_fields ~w(id name description url
    bookmark_parameter1 bookmark_parameter2
    bookmark_parameter3)a
  @object_modes ~w(all none whitelisted)

  def new(params \\ []) do
    defaults = [
      name: "",
      unique_token: UUID.uuid4(),
      branch_mode: "all",
      tag_mode: "all",
      pr_mode: "all"
    ]

    struct(__MODULE__, Keyword.merge(defaults, Enum.to_list(params)))
  end

  def validate(target \\ new(), params) do
    target_changeset = changeset(target, params)

    if target_changeset.valid?,
      do: {:ok, target_changeset},
      else: {:error, target_changeset}
  end

  def changeset(params \\ %{}) do
    changeset(new(), params)
  end

  def changeset(target, params) do
    target
    |> Ecto.Changeset.cast(params, @fields)
    |> Ecto.Changeset.validate_required(@required)
    |> Ecto.Changeset.validate_length(:name, max: 255)
    |> Ecto.Changeset.validate_format(:name, ~r/^[A-Za-z0-9_\.\-]+$/,
      message: "must contain only alphanumericals, dashes, underscores or dots"
    )
    |> Ecto.Changeset.validate_inclusion(:branch_mode, @object_modes)
    |> Ecto.Changeset.validate_inclusion(:tag_mode, @object_modes)
    |> Ecto.Changeset.validate_inclusion(:pr_mode, @object_modes -- ["whitelisted"])
    |> Ecto.Changeset.cast_embed(:env_vars)
    |> Ecto.Changeset.cast_embed(:files)
    |> validate_objects(:branch_mode, :branches)
    |> validate_objects(:tag_mode, :tags)
  end

  defp validate_objects(changeset, object_mode, objects) do
    if "whitelisted" == Ecto.Changeset.get_field(changeset, object_mode),
      do: Ecto.Changeset.cast_embed(changeset, objects, required: true),
      else: Ecto.Changeset.put_embed(changeset, objects, [])
  end

  # model mapping

  def from_api(target, secret_data) do
    new()
    |> changeset(
      target
      |> Map.take(@plain_fields)
      |> Map.merge(secret_data_from_api(secret_data))
      |> Map.merge(subjects_from_api(target.subject_rules))
      |> Map.merge(objects_from_api(target.object_rules))
    )
    |> Ecto.Changeset.apply_changes()
  end

  defp secret_data_from_api(secret_data) do
    %{
      env_vars: creds_from_api(secret_data.env_vars, {:name, :value}),
      files: creds_from_api(secret_data.files, {:path, :content})
    }
  end

  defp creds_from_api(collection, {key, value}) do
    collection
    |> Stream.map(&Map.take(&1, [key, value]))
    |> Stream.map(&Map.put(&1, :id, Map.get(&1, key)))
    |> Stream.map(&Map.put(&1, :md5, md5_checksum(&1, value)))
    |> Enum.into([], &Map.put(&1, value, ""))
  end

  defp md5_checksum(credential, value),
    do: credential |> Map.get(value) |> :erlang.md5() |> Base.encode16(case: :lower)

  defp subjects_from_api(subject_rules) do
    has_any_rule? = Enum.any?(subject_rules, &(&1.type == :ANY))

    roles = subject_ids(subject_rules, :ROLE)
    members = subject_ids(subject_rules, :USER)
    auto_promotions = auto_promotions?(subject_rules)

    if has_any_rule? do
      %{user_access: "any", roles: [], members: [], auto_promotions: false}
    else
      %{user_access: "some", roles: roles, members: members, auto_promotions: auto_promotions}
    end
  end

  defp subject_ids(subject_rules, type) do
    subject_rules
    |> Stream.filter(&(&1.type == type))
    |> Enum.into([], & &1.subject_id)
  end

  defp auto_promotions?(subject_rules) do
    Enum.any?(subject_rules, &(&1.type == :AUTO))
  end

  defp objects_from_api(object_rules) do
    {branch_mode, branches} = find_mode_and_items(object_rules, :BRANCH)
    {tag_mode, tags} = find_mode_and_items(object_rules, :TAG)
    {pr_mode, _} = find_mode_and_items(object_rules, :PR)
    pr_mode = if pr_mode == "whitelisted", do: "none", else: pr_mode

    %{
      branches: branches,
      tags: tags,
      branch_mode: branch_mode,
      tag_mode: tag_mode,
      pr_mode: pr_mode
    }
  end

  defp find_mode_and_items(object_rules, type) do
    object_items =
      object_rules
      |> Stream.filter(&(&1.type == type))
      |> Enum.into([], &Map.take(&1, ~w(match_mode pattern)a))

    all_match_modes = MapSet.new(object_items, & &1.match_mode)

    cond do
      MapSet.member?(all_match_modes, :ALL) -> {"all", []}
      Enum.empty?(all_match_modes) -> {"none", []}
      true -> {"whitelisted", Enum.map(object_items, &map_match_mode/1)}
    end
  end

  defp map_match_mode(object_item) do
    alias InternalApi.Gofer.DeploymentTargets.ObjectRule
    match_mode = ObjectRule.Mode.value(object_item.match_mode)
    Map.put(object_item, :match_mode, match_mode)
  end

  # target model extraction

  def to_api(model = %__MODULE__{}, extra_params) do
    model
    |> Map.take(@plain_fields)
    |> Map.merge(extra_params)
    |> Map.put(:subject_rules, subjects_for_api(model))
    |> Map.put(:object_rules, objects_for_api(model))
  end

  defp subjects_for_api(model = %__MODULE__{user_access: "some"}) do
    auto_rules = if model.auto_promotions, do: %{type: :AUTO, subject_id: ""}
    role_rules = Enum.map(model.roles, &%{type: :ROLE, subject_id: &1})
    member_rules = Enum.map(model.members, &%{type: :USER, subject_id: &1})
    List.wrap(auto_rules) ++ role_rules ++ member_rules
  end

  defp subjects_for_api(_model = %__MODULE__{user_access: _any}) do
    [%{type: :ANY, subject_id: ""}]
  end

  defp objects_for_api(model = %__MODULE__{}) do
    branch_rules_for_api(model) ++ tag_rules_for_api(model) ++ pr_rules_for_api(model)
  end

  defp branch_rules_for_api(%__MODULE__{branch_mode: "none"}), do: []

  defp branch_rules_for_api(%__MODULE__{branch_mode: "all"}),
    do: [%{type: :BRANCH, match_mode: :ALL, pattern: ""}]

  defp branch_rules_for_api(%__MODULE__{branch_mode: "whitelisted", branches: branches}),
    do: Enum.map(branches, &(&1 |> Map.take(~w(match_mode pattern)a) |> Map.put(:type, :BRANCH)))

  defp tag_rules_for_api(%__MODULE__{tag_mode: "none"}), do: []

  defp tag_rules_for_api(%__MODULE__{tag_mode: "all"}),
    do: [%{type: :TAG, match_mode: :ALL, pattern: ""}]

  defp tag_rules_for_api(%__MODULE__{tag_mode: "whitelisted", tags: tags}),
    do: Enum.map(tags, &(&1 |> Map.take(~w(match_mode pattern)a) |> Map.put(:type, :TAG)))

  defp pr_rules_for_api(%__MODULE__{pr_mode: "none"}), do: []

  defp pr_rules_for_api(%__MODULE__{pr_mode: "all"}),
    do: [%{type: :PR, match_mode: :ALL, pattern: ""}]

  # secret extraction & consolidation

  def extract_secret_data(changeset = %Ecto.Changeset{}) do
    extract_secret_data(changeset, %{env_vars: [], files: []})
  end

  def extract_secret_data(changeset = %Ecto.Changeset{}, secret_data) do
    if credentials_changed?(changeset) do
      old_env_vars = Map.new(secret_data.env_vars, &{&1.name, &1.value})
      old_files = Map.new(secret_data.files, &{&1.path, &1.content})

      model = Ecto.Changeset.apply_changes(changeset)
      env_vars = Enum.into(model.env_vars, [], &consolidate!(&1, old_env_vars))
      files = Enum.into(model.files, [], &consolidate!(&1, old_files))

      {:ok, %{env_vars: env_vars, files: files}}
    else
      {:ok, :no_changes}
    end
  rescue
    KeyError ->
      message = "Secret was modified in the meantime"
      {:error, %Front.Models.DeploymentsError{message: message}}
  end

  defp credentials_changed?(changeset = %Ecto.Changeset{}) do
    old_env_vars = MapSet.new(changeset.data.env_vars)
    old_files = MapSet.new(changeset.data.files)

    new_model = Ecto.Changeset.apply_changes(changeset)
    new_env_vars = MapSet.new(new_model.env_vars)
    new_files = MapSet.new(new_model.files)

    !MapSet.equal?(old_env_vars, new_env_vars) || !MapSet.equal?(old_files, new_files)
  end

  defp consolidate!(env_var = %EnvVar{id: ""}, _old_env_vars),
    do: %{name: env_var.name, value: env_var.value}

  defp consolidate!(env_var = %EnvVar{value: ""}, old_env_vars),
    do: %{name: env_var.name, value: Map.fetch!(old_env_vars, env_var.id)}

  defp consolidate!(env_var = %EnvVar{}, _old_env_vars),
    do: %{name: env_var.name, value: env_var.value}

  defp consolidate!(file = %File{id: ""}, _old_files),
    do: %{path: file.path, content: file.content}

  defp consolidate!(file = %File{content: ""}, old_files),
    do: %{path: file.path, content: Map.fetch!(old_files, file.id)}

  defp consolidate!(file = %File{}, _old_files),
    do: %{path: file.path, content: file.content}
end
