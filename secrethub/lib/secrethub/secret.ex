defmodule Secrethub.Secret do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  require Logger

  alias Secrethub.Repo
  alias Secrethub.Model.Content

  @primary_key {:id, :binary_id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime_usec]

  @valid_name_regex ~r/^[@: -._a-zA-Z0-9]+$/
  @invalid_name_msg "name can only include alpha-numeric characters, dashes, underscores and dots"

  schema "secrets" do
    field(:org_id, :binary_id)
    field(:name, :string)
    field(:description, :string, default: "")

    # This is a virtual field, because it is not persistent into the DB.
    # This is a field which is computed from the `content_encrypted` one.
    field(:content, :map, virtual: true)
    field(:content_encrypted, :binary, default: nil)

    field(:all_projects, :boolean)
    field(:project_ids, {:array, :string})

    field(:used_at, :utc_datetime)
    field(:created_by, :string)
    field(:updated_by, :string)
    field(:used_by, :map)

    field(:job_debug, :integer)
    field(:job_attach, :integer)

    timestamps()
  end

  #
  # Lookup
  #

  def find(org_id, id, project_id \\ "") do
    query =
      __MODULE__
      |> in_project(project_id)

    case Repo.get_by(query, org_id: org_id, id: id) do
      nil -> {:error, :not_found}
      secret -> Secrethub.Encryptor.decrypt_secret(secret)
    end
  end

  def find_by_name(org_id, name, project_id \\ "") do
    query =
      __MODULE__
      |> in_project(project_id)

    case Repo.get_by(query, org_id: org_id, name: name) do
      nil -> {:error, :not_found}
      secret -> Secrethub.Encryptor.decrypt_secret(secret)
    end
  end

  def find_by_id_or_name(org_id, id_or_name, project_id \\ "") do
    if uuid?(id_or_name) do
      find(org_id, id_or_name, project_id)
    else
      find_by_name(org_id, id_or_name, project_id)
    end
  end

  def uuid?(id_or_name) do
    String.match?(id_or_name, ~r/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/)
  end

  def load(secret_ids) when is_list(secret_ids) do
    entries =
      Secrethub.Secret
      |> where([s], s.id in ^secret_ids)
      |> order_by([s], s.inserted_at)
      |> Repo.all()
      |> Enum.map(fn s ->
        case Secrethub.Encryptor.decrypt_secret(s) do
          {:ok, secret} -> secret
          _ -> nil
        end
      end)

    {:ok, entries}
  end

  def load(req) do
    cond do
      Map.get(req, :ids, []) != [] ->
        load(req.ids)

      req.names != [] ->
        entries =
          __MODULE__
          |> in_org(req.metadata.org_id)
          |> in_project(req.project_id)
          |> where([s], s.name in ^req.names)
          |> Repo.all()

        # order entries in the same order as requested
        entries =
          req.names
          |> Enum.map(fn name -> Enum.find(entries, fn e -> e.name == name end) end)
          |> Enum.filter(fn s -> s != nil end)
          |> Enum.map(fn s ->
            case Secrethub.Encryptor.decrypt_secret(s) do
              {:ok, secret} -> secret
              _ -> nil
            end
          end)

        {:ok, entries}

      true ->
        # handle empty requests
        {:ok, []}
    end
  end

  #
  # Scopes
  #

  def order_by_name_asc(query) do
    query |> order_by([s], s.name)
  end

  def order_by_create_time_asc(query) do
    query |> order_by([s], s.inserted_at)
  end

  def in_org(query, org_id) do
    query |> where([s], s.org_id == ^org_id)
  end

  def in_project(query, ""), do: query

  def in_project(query, project_id) do
    query |> where([s], s.all_projects == true or ^project_id in s.project_ids)
  end

  #
  # Modification
  #

  def save(org_id, user_id, name, content) do
    change =
      %__MODULE__{}
      |> changeset(%{
        org_id: org_id,
        name: name,
        content: content,
        created_by: user_id,
        updated_by: user_id
      })

    case Repo.insert(change) do
      {:ok, secret} -> Secrethub.Encryptor.decrypt_secret(secret)
      {:error, changeset} -> process_save_errors(changeset.errors)
    end
  end

  def save(
        org_id,
        user_id,
        name,
        description,
        content,
        org_permissions
      ) do
    change =
      %__MODULE__{}
      |> changeset(
        Map.merge(
          %{
            org_id: org_id,
            name: name,
            description: description,
            content: content,
            created_by: user_id,
            updated_by: user_id
          },
          org_permissions
        )
      )

    case Repo.insert(change) do
      {:ok, secret} -> Secrethub.Encryptor.decrypt_secret(secret)
      {:error, changeset} -> process_save_errors(changeset.errors)
    end
  end

  def process_save_errors([{:unique_names, {message, _}} | _]) do
    {:error, :failed_precondition, message}
  end

  def process_save_errors([{:name_format, {message, _}} | _]) do
    {:error, :failed_precondition, message}
  end

  def process_save_errors([{:empty_field, {message, _}} | _]) do
    {:error, :failed_precondition, message}
  end

  def process_save_errors([{:name, {message, [validation: :format]}} | _]) do
    {:error, :failed_precondition, message}
  end

  def process_save_errors([{:content, {message, _}} | _]) do
    {:error, :failed_precondition, message}
  end

  def process_save_errors([{:env_vars, {message, _}} | _]) do
    {:error, :failed_precondition, message}
  end

  def process_save_errors([{:files, {message, _}} | _]) do
    {:error, :failed_precondition, message}
  end

  def process_save_errors([{:size, {message, _}} | _]) do
    {:error, :failed_precondition, message}
  end

  def process_save_errors(e) do
    Logger.error(inspect(e))

    {:error, :unknown, "Unknown error"}
  end

  def update(org_id, user_id, old_secret, new_name, new_content) do
    #
    # Some old secrets in the db had invalid names. Ignore them.
    #
    validate_name? = Regex.match?(@valid_name_regex, old_secret.name)

    change =
      changeset(
        old_secret,
        %{
          org_id: org_id,
          name: new_name,
          content: new_content,
          updated_by: user_id
        },
        validate_name?
      )

    case Repo.update(change) do
      {:ok, secret} -> Secrethub.Encryptor.decrypt_secret(secret)
      {:error, changeset} -> process_save_errors(changeset.errors)
    end
  end

  def update(org_id, user_id, old_secret, params) do
    #
    # Some old secrets in the db had invalid names. Ignore them.
    #
    validate_name? = Regex.match?(@valid_name_regex, old_secret.name)

    params =
      params
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Map.new()
      |> Map.put(:updated_by, user_id)
      |> Map.put(:org_id, org_id)

    change =
      changeset(
        old_secret,
        params,
        validate_name?
      )

    case Repo.update(change) do
      {:ok, secret} -> Secrethub.Encryptor.decrypt_secret(secret)
      {:error, changeset} -> process_save_errors(changeset.errors)
    end
  end

  def delete(secret) do
    Repo.delete(secret)
  end

  def update_usage(secret, user) do
    change =
      secret
      |> Ecto.Changeset.change(%{used_by: user, used_at: time_now()})
      |> Ecto.Changeset.force_change(:updated_at, secret.updated_at)

    case Repo.update(change) do
      {:ok, secret} -> {:ok, secret}
      {:error, changeset} -> process_save_errors(changeset.errors)
    end
  end

  defp time_now, do: DateTime.truncate(DateTime.utc_now(), :second)

  def changeset(secret, params \\ %{}, validate_name? \\ true) do
    content = Map.get(params.content, "data", %{})

    case apply_action(Content.changeset(%Content{}, content), :update) do
      {:ok, validated_content} ->
        params = Map.put(params, :content, validated_content)

        secret
        |> cast(params, [
          :org_id,
          :name,
          :description,
          :content,
          :content_encrypted,
          :all_projects,
          :project_ids,
          :used_at,
          :created_by,
          :updated_by,
          :used_by,
          :job_debug,
          :job_attach
        ])
        |> validate_required([:name, :org_id, :content])
        |> validate_length(:description, min: 0, max: 255)
        |> unique_constraint(:unique_names,
          name: :unique_names_in_organization,
          message: "name has already been taken"
        )
        |> valid_name_format(params, validate_name?)
        |> Secrethub.Encryptor.encrypt_changeset(params, :content)

      {:error, changeset} ->
        change(%__MODULE__{})
        |> add_error(:content, Content.consolidate_changeset_errors(changeset))
    end
  end

  defp valid_name_format(changeset, params, true) do
    if changeset.valid? do
      changeset =
        changeset |> validate_format(:name, @valid_name_regex, message: @invalid_name_msg)

      if uuid?(params.name) do
        changeset |> add_error(:name_format, "name should not be in uuid format")
      else
        changeset
      end
    else
      changeset
    end
  end

  defp valid_name_format(changeset, _params, false), do: changeset
end
