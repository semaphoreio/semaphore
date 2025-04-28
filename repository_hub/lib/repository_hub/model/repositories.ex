defmodule RepositoryHub.Model.Repositories do
  @moduledoc """
  Repositories type

  Stores data about repositories
  """
  use RepositoryHub.Repo

  alias __MODULE__
  alias RepositoryHub.Toolkit

  @default_yaml_location ".semaphore/semaphore.yml"

  @type t :: %__MODULE__{}

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "repositories" do
    field(:project_id, :binary_id)
    field(:name, :string, default: "")
    field(:owner, :string, default: "")
    field(:private, :boolean)
    field(:provider, :string)
    field(:integration_type, :string)
    field(:url, :string)
    field(:pipeline_file, :string, default: @default_yaml_location)
    field(:connected, :boolean, default: true)
    field(:enable_commit_status, :boolean, default: true)
    field(:commit_status, :map)
    field(:whitelist, :map)
    field(:hook_id, :string)
    field(:hook_secret_enc, :binary)
    field(:default_branch, :string, default: "master")
    field(:remote_id, :string)

    timestamps(inserted_at_source: :created_at)
  end

  @fields ~w(project_id name owner private provider integration_type
    url pipeline_file hook_id hook_secret_enc connected commit_status whitelist
    default_branch remote_id)a
  @required_fields ~w(project_id integration_type url)a

  @spec changeset(Repositories.t()) :: Ecto.Changeset.t()
  def changeset(repository \\ %Repositories{}, params \\ %{}) do
    repository
    |> cast(params, @fields)
    |> validate_required(@required_fields)
  end

  def to_grpc_model(model) do
    hook_id =
      model.hook_id
      |> case do
        nil -> ""
        other -> "#{other}"
      end

    %InternalApi.Repository.Repository{
      id: model.id,
      name: model.name,
      owner: model.owner,
      private: model.private,
      provider: model.provider,
      url: model.url,
      project_id: model.project_id,
      pipeline_file: model.pipeline_file,
      hook_id: hook_id,
      commit_status: commit_status(model.commit_status),
      whitelist: whitelist(model.whitelist),
      integration_type: to_integration_type(model.integration_type),
      default_branch: model.default_branch
    }
  end

  @doc """
    Validates if incoming hook has a valid signature.

    The signature is verified using the secret stored in the database.
  """
  @spec hook_signature_valid?(
          repository :: t(),
          payload :: String.t(),
          signature :: String.t()
        ) :: Toolkit.tupled_result(boolean)
  def hook_signature_valid?(repository, payload, signature) do
    with {:ok, secret} <- get_signing_secret(repository),
         signature_matches? <- compare_signature(signature, secret, payload),
         secret_matches? <- compare_secret(signature, secret),
         result <- signature_matches? or secret_matches? do
      {:ok, result}
    else
      {:error, :no_secret} ->
        {:ok, false}
    end
  end

  defp get_signing_secret(%{id: repository_id, hook_secret_enc: secret_enc})
       when is_binary(secret_enc) and secret_enc != "" do
    secret =
      RepositoryHub.Encryptor.decrypt!(
        RepositoryHub.WebhookSecretEncryptor,
        secret_enc,
        repository_id
      )

    {:ok, secret}
  end

  defp get_signing_secret(_), do: {:error, :no_secret}

  defp compare_signature(signature, secret, payload) do
    if String.starts_with?(signature, "sha256=") do
      calculated_signature =
        :crypto.mac(:hmac, :sha256, secret, payload)
        |> Base.encode16()
        |> String.trim_trailing()
        |> String.downcase()

      secure_compare("sha256=#{calculated_signature}", signature)
    else
      false
    end
  end

  defp compare_secret(signature, secret) do
    secure_compare(signature, secret)
  end

  defp secure_compare(left, right) do
    byte_size(left) == byte_size(right) and :crypto.hash_equals(left, right)
  end

  @spec generate_hook_secret(t()) :: {:ok, {String.t(), binary()}} | {:error, any()}
  def generate_hook_secret(repository) do
    secret =
      :crypto.strong_rand_bytes(32)
      |> Base.encode64()

    RepositoryHub.Encryptor.encrypt(RepositoryHub.WebhookSecretEncryptor, secret, repository.id)
    |> case do
      {:ok, secret_enc} ->
        {:ok, {secret, secret_enc}}

      error ->
        error
    end
  end

  defp to_integration_type(value) do
    value
    |> String.upcase()
    |> String.to_atom()
  end

  defp whitelist(nil),
    do: %InternalApi.Projecthub.Project.Spec.Repository.Whitelist{branches: [], tags: []}

  defp whitelist(whitelist) do
    %InternalApi.Projecthub.Project.Spec.Repository.Whitelist{
      branches: Map.get(whitelist, "branches", []),
      tags: Map.get(whitelist, "tags", [])
    }
  end

  defp commit_status(nil),
    do: %InternalApi.Projecthub.Project.Spec.Repository.Status{pipeline_files: []}

  defp commit_status(commit_status) do
    files =
      Map.get(commit_status, "pipeline_files", [])
      |> Enum.map(fn pf ->
        level = pf["level"] |> String.upcase() |> String.to_atom()
        path = pf["path"]

        %InternalApi.Projecthub.Project.Spec.Repository.Status.PipelineFile{
          path: path,
          level: level
        }
      end)

    %InternalApi.Projecthub.Project.Spec.Repository.Status{pipeline_files: files}
  end

  def default_yaml_location do
    @default_yaml_location
  end
end
