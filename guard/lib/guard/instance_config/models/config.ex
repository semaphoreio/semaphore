defmodule Guard.InstanceConfig.Models.Config do
  use Ecto.Schema
  import Ecto.Changeset
  alias Guard.InstanceConfig.Models

  @primary_key false
  schema "integration_config" do
    field(:name, :string, primary_key: true)

    field(:config, :map, virtual: true)
    field(:config_encrypted, :binary, default: nil)

    timestamps(type: :utc_datetime)
  end

  def changeset(integration_config \\ %__MODULE__{}, params) do
    integration_config
    |> cast(params, [:name])
    |> cast_config(params)
    |> put_encrypted_config()
    |> validate_required([:name, :config_encrypted])
  end

  defp cast_config(changeset, params) do
    params
    |> config_changeset()
    |> apply_action(:update)
    |> case do
      {:ok, config} ->
        put_change(changeset, :config, config)

      {:error, errored_config_changeset} ->
        changeset
        |> add_error(
          :config,
          Models.Utils.consolidate_changeset_errors(errored_config_changeset)
        )
    end
  end

  defp config_changeset(params) do
    case params[:name] do
      "CONFIG_TYPE_GITHUB_APP" ->
        Models.GithubApp.changeset(%Models.GithubApp{}, params[:config])

      "CONFIG_TYPE_BITBUCKET_APP" ->
        Models.BitbucketApp.changeset(%Models.BitbucketApp{}, params[:config])

      "CONFIG_TYPE_GITLAB_APP" ->
        Models.GitlabApp.changeset(%Models.GitlabApp{}, params[:config])

      "CONFIG_TYPE_INSTALLATION_DEFAULTS" ->
        Models.InstallationDefaults.changeset(%Models.InstallationDefaults{}, params[:config])

      _ ->
        %Ecto.Changeset{}
        |> add_error(:config, "Invalid config type: #{params[:name]}")
    end
  end

  defp put_encrypted_config(changeset) do
    if data = get_change(changeset, :config) do
      name = get_field(changeset, :name)
      encrypted_data = encrypt!(data, name)
      put_change(changeset, :config_encrypted, encrypted_data)
    else
      changeset
    end
  end

  def encrypt!(config, assoc_data) do
    Guard.Encryptor.encrypt!(
      Guard.InstanceConfig.Encryptor,
      config |> Jason.encode!(),
      assoc_data
    )
  end

  def decrypt!(%__MODULE__{name: type, config_encrypted: config} = integration_config) do
    config =
      Guard.Encryptor.decrypt!(
        Guard.InstanceConfig.Encryptor,
        config,
        integration_config.name
      )
      |> Jason.decode!(keys: :atoms)

    config = struct(type_to_model(type), config |> Map.to_list())

    %{
      integration_config
      | config: config
    }
  end

  defp type_to_model("CONFIG_TYPE_GITHUB_APP"), do: Models.GithubApp
  defp type_to_model("CONFIG_TYPE_BITBUCKET_APP"), do: Models.BitbucketApp
  defp type_to_model("CONFIG_TYPE_GITLAB_APP"), do: Models.GitlabApp
  defp type_to_model("CONFIG_TYPE_INSTALLATION_DEFAULTS"), do: Models.InstallationDefaults
end
