defmodule Audit.Streamer.Config do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Audit.Encryptor, as: Encryptor

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "streamers" do
    field(:org_id, :binary_id)
    field(:provider, :integer)

    field(:status, :integer)
    field(:last_streamed, :utc_datetime)

    # # # # metadata contains json
    # S3  # bucket_name, host
    field(:metadata, :map)

    # # # # cridentials contains json
    # S3  # key_id, key_secret, type
    #     # type is INSTANCE_ROLE or USER
    field(:cridentials, :map, virtual: true)
    field(:encrypted_credentials, :binary, default: nil)

    field(:created_at, :utc_datetime)
    field(:updated_at, :utc_datetime)
    field(:activity_toggled_at, :utc_datetime)
    field(:updated_by, :binary_id)
    field(:activity_toggled_by, :binary_id)
  end

  def create(params) do
    defaults = %{status: InternalApi.Audit.StreamStatus.value(:ACTIVE)}
    params = Map.merge(defaults, params)

    %__MODULE__{}
    |> changeset(params)
    |> Audit.Repo.insert()
    |> case do
      {:ok, config} ->
        {:ok, config}

      {:error, changeset} ->
        {:error, changeset_errors_to_string(changeset)}
    end
  end

  def update(filter, params) do
    default = %{org_id: :skip, provider: :skip, stream_id: :skip}
    filter = Map.merge(default, filter)

    __MODULE__
    |> filter_by_stream_id(filter.stream_id)
    |> filter_by_org_id(filter.org_id)
    |> filter_by_provider(filter.provider)
    |> Audit.Repo.one()
    |> changeset(params)
    |> Audit.Repo.update()
    |> case do
      {:ok, config} ->
        {:ok, config}

      {:error, changeset} ->
        {:error, changeset_errors_to_string(changeset)}
    end
  end

  def get(org_id) do
    __MODULE__
    |> where([e], e.org_id == ^org_id)
    |> Audit.Repo.all()
    |> Enum.map(fn config -> unserialize(config) end)
  end

  def get_one(filter) do
    result = get_one!(filter)

    case result do
      nil ->
        {:not_found, nil}

      result ->
        {:ok, result}
    end
  rescue
    e ->
      {:error, inspect(e)}
  end

  def get_one!(filter) do
    default = %{org_id: :skip, provider: :skip, stream_id: :skip}
    filter = Map.merge(default, filter)

    __MODULE__
    |> filter_by_org_id(filter.org_id)
    |> filter_by_provider(filter.provider)
    |> filter_by_stream_id(filter.stream_id)
    |> Audit.Repo.one()
    |> unserialize
  end

  defp filter_by_stream_id(query, :skip), do: query

  defp filter_by_stream_id(query, stream_id),
    do: query |> where([e], e.id == ^stream_id)

  defp filter_by_org_id(query, :skip), do: query

  defp filter_by_org_id(query, org_id),
    do: query |> where([e], e.org_id == ^org_id)

  defp filter_by_provider(query, :skip), do: query

  defp filter_by_provider(query, provider),
    do: query |> where([e], e.provider == ^provider)

  def delete(org_id) do
    {:ok, delete!(org_id)}
  rescue
    e ->
      {:error, e.message}
  end

  def delete!(org_id) do
    case Audit.Repo.get_by(__MODULE__, org_id: org_id) do
      nil -> raise "No stream found for org_id: #{inspect(org_id)}"
      config -> Audit.Repo.delete(config)
    end
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [
      :org_id,
      :provider,
      :status,
      :last_streamed,
      :metadata,
      :cridentials,
      :created_at,
      :updated_at,
      :activity_toggled_at,
      :updated_by,
      :activity_toggled_by
    ])
    |> validate_metadata_host()
    |> maybe_encrypt_credentials(params)
  end

  @doc """
  Converts keys to atoms in metadata, and unserializes provider enum
  """
  def unserialize(nil), do: nil

  def unserialize(config) do
    config
    |> convert_keys_to_atoms()
    |> Map.put(:provider, InternalApi.Audit.StreamProvider.key(config.provider))
    |> Map.put(:status, InternalApi.Audit.StreamStatus.key(config.status))
  end

  def api_to_metadata(s3_config = %InternalApi.Audit.S3StreamConfig{}) do
    api_to_metadata(%{provider: :S3, s3_config: s3_config})
  end

  def api_to_metadata(stream = %{s3_config: %{type: :INSTANCE_ROLE}}) do
    case stream.provider do
      :S3 ->
        %{
          bucket_name: stream.s3_config.bucket,
          region: stream.s3_config.region
        }
    end
  end

  def api_to_metadata(stream) do
    case stream.provider do
      :S3 ->
        %{
          bucket_name: stream.s3_config.bucket,
          host: stream.s3_config.host,
          region: stream.s3_config.region
        }
    end
  end

  def api_to_cridentials(s3_config = %InternalApi.Audit.S3StreamConfig{}) do
    api_to_metadata(%{provider: :S3, s3_config: s3_config})
  end

  def api_to_cridentials(stream = %{s3_config: %{type: :INSTANCE_ROLE}}) do
    case stream.provider do
      :S3 ->
        %{
          type: "INSTANCE_ROLE"
        }
    end
  end

  def api_to_cridentials(stream) do
    case stream.provider do
      :S3 ->
        %{
          key_id: Map.get(stream.s3_config, :key_id, ""),
          key_secret: Map.get(stream.s3_config, :key_secret, ""),
          type: Map.get(stream.s3_config, :type, :USER) |> to_string
        }
    end
  end

  def metadata_to_api(stream) do
    case stream.provider do
      :S3 ->
        InternalApi.Audit.S3StreamConfig.new(
          bucket: stream.metadata.bucket_name,
          host: Map.get(stream.metadata, :host, ""),
          key_id: Map.get(stream.cridentials, :key_id, ""),
          key_secret: Map.get(stream.cridentials, :key_secret, ""),
          region: Map.get(stream.metadata, :region, ""),
          type: to_credentials_type_atom(stream.cridentials)
        )
    end
  end

  defp convert_keys_to_atoms(nil), do: nil

  defp convert_keys_to_atoms(config) do
    %{
      metadata: metadata,
      encrypted_credentials: encrypted_credentials,
      org_id: org_id
    } = config

    credentials =
      if encrypted_credentials == nil,
        do: nil,
        else:
          Audit.CredentialsEncryptor
          |> Encryptor.decrypt!(encrypted_credentials, org_id)
          |> Poison.decode!()

    atom_key_map_metadata =
      Map.new(metadata, fn {k, v} ->
        {String.to_existing_atom(k), v}
      end)

    # prevents nil credentials from being passed to Map.new
    credentials = credentials || %{}

    atom_key_map_credentials =
      Map.new(credentials, fn {k, v} ->
        {String.to_existing_atom(k), v}
      end)

    config = Map.put(config, :metadata, atom_key_map_metadata)
    Map.put(config, :cridentials, atom_key_map_credentials)
  end

  defp to_credentials_type_atom(_cridentials = %{type: credentials_type}),
    do: String.to_atom(credentials_type)

  defp to_credentials_type_atom(_cridentials), do: :USER

  defp validate_metadata_host(changeset) do
    changeset
    |> get_field(:metadata)
    |> case do
      %{host: host} when host != "" and not is_nil(host) ->
        Audit.NetworkUtils.internal_url?(host)
        |> case do
          true -> add_error(changeset, :metadata, "host is invalid")
          false -> changeset
        end

      _ ->
        changeset
    end
  end

  @spec changeset_errors_to_string(Ecto.Changeset.t()) :: String.t()
  defp changeset_errors_to_string(changeset) do
    changeset.errors
    |> Enum.map_join(", ", fn
      {:metadata, {"host is invalid", _options}} ->
        "invalid host"

      {field, {message, _options}} ->
        "#{field} #{message}"
    end)
  end

  defp maybe_encrypt_credentials(changeset, params) do
    updated_params =
      if Map.has_key?(params, :org_id),
        do: params,
        else: Map.put(params, :org_id, changeset.data.org_id)

    if Map.get(updated_params, :cridentials) != nil do
      changeset
      |> encrypt_credentials(updated_params)
    else
      changeset
    end
  end

  defp encrypt_credentials(changeset, params) do
    require Logger

    if changeset.valid? do
      case Encryptor.encrypt(
             Audit.CredentialsEncryptor,
             Poison.encode!(Map.get(params, :cridentials)),
             params.org_id
           ) do
        {:ok, encrypted} ->
          changeset
          |> Ecto.Changeset.change(encrypted_credentials: encrypted)

        e ->
          Logger.error("Failed to encrypt '#{params.org_id}': #{inspect(e)}")

          changeset
          |> Ecto.Changeset.add_error(:encryption, "failed to encrypt credentials")
      end
    else
      changeset
      |> Ecto.Changeset.change(encrypted_credentials: nil)
    end
  end
end
