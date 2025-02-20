defmodule Gofer.Deployment.Model.Deployment do
  @moduledoc """
  Stores deployment target and its status data
  """
  use Ecto.Schema

  alias Gofer.Deployment.Model.Deployment.EncryptedSecret
  alias Gofer.Deployment.Model.Deployment.SubjectRule
  alias Gofer.Deployment.Model.Deployment.ObjectRule

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @timestamps_opts type: :naive_datetime_usec
  schema "deployments" do
    field(:name, :string)
    field(:description, :string)
    field(:url, :string)

    field(:organization_id, :string)
    field(:project_id, :string)

    field(:created_by, :string)
    field(:updated_by, :string)
    field(:unique_token, :string)

    field(:secret_id, :string)
    field(:secret_name, :string)

    field(:state, Ecto.Enum,
      values: [:SYNCING, :FINISHED],
      default: :SYNCING
    )

    field(:result, Ecto.Enum,
      values: [:SUCCESS, :FAILURE],
      default: :SUCCESS
    )

    field(:cordoned, :boolean, default: false)

    field(:bookmark_parameter1, :string)
    field(:bookmark_parameter2, :string)
    field(:bookmark_parameter3, :string)

    embeds_one(:encrypted_secret, EncryptedSecret, on_replace: :delete)
    embeds_many(:subject_rules, SubjectRule, on_replace: :delete)
    embeds_many(:object_rules, ObjectRule, on_replace: :delete)

    timestamps()
  end

  @params ~w(name description url
            organization_id project_id
            created_by updated_by unique_token
            bookmark_parameter1
            bookmark_parameter2
            bookmark_parameter3)a
  @required ~w(name organization_id project_id
            created_by updated_by unique_token
            state result)a

  def changeset(deployment, params) do
    deployment
    |> Ecto.Changeset.cast(params, @params)
    |> Ecto.Changeset.cast_embed(:subject_rules)
    |> Ecto.Changeset.cast_embed(:object_rules)
    |> Ecto.Changeset.validate_required(@required)
    |> Ecto.Changeset.validate_length(:name, max: 255)
    |> Ecto.Changeset.validate_format(:name, ~r/^[A-Za-z0-9_\.\-]+$/,
      message: "must contain only alphanumericals, dashes, underscores or dots"
    )
    |> Ecto.Changeset.unique_constraint([:name],
      name: :unique_deployments_per_project
    )
    |> Ecto.Changeset.unique_constraint([:unique_token],
      name: :unique_deployments_per_unique_token
    )
  end

  def set_as_syncing(deployment, unique_token) do
    Ecto.Changeset.change(deployment, %{state: :SYNCING, unique_token: unique_token})
  end

  def set_as_finished(deployment, result) do
    deployment
    |> Ecto.Changeset.cast(%{result: result}, [:result])
    |> Ecto.Changeset.put_change(:state, :FINISHED)
    |> Ecto.Changeset.validate_required([:state, :result])
  end

  def put_secret(deployment, secret_params) do
    deployment
    |> Ecto.Changeset.cast(secret_params, [:secret_id, :secret_name])
    |> Ecto.Changeset.validate_required([:secret_id, :secret_name])
  end

  def put_encrypted_secret(deployment, secret = %EncryptedSecret{}) do
    deployment
    |> Ecto.Changeset.cast(%{encrypted_secret: secret}, [])
    |> Ecto.Changeset.put_embed(:encrypted_secret, secret)
  end

  def put_encrypted_secret(deployment, secret = %Ecto.Changeset{}) do
    changeset =
      deployment
      |> Ecto.Changeset.cast(%{encrypted_secret: secret}, [])
      |> Ecto.Changeset.put_embed(:encrypted_secret, secret)

    if secret.valid?,
      do: changeset,
      else:
        Ecto.Changeset.add_error(
          changeset,
          :encrypted_secret,
          "is invalid",
          secret.errors
        )
  end

  def put_encrypted_secret(deployment, secret) do
    deployment
    |> Ecto.Changeset.cast(%{encrypted_secret: secret}, [])
    |> Ecto.Changeset.cast_embed(:encrypted_secret)
  end
end
