defmodule Gofer.Deployment.Model.Deployment.EncryptedSecret do
  @moduledoc """
  Encapsulates necessary data for DT secret synchronization
  """

  use Ecto.Schema

  @requests ~w(create update delete)a
  @encrypted_secret_fields ~w(key_id aes256_key init_vector payload)a
  @all_fields ~w(
    request_type requester_id unique_token error_message
    key_id aes256_key init_vector payload
  )a
  @required_fields ~w(request_type requester_id unique_token)a

  @primary_key false
  embedded_schema do
    field(:request_type, Ecto.Enum, values: @requests)
    field(:requester_id, :string)
    field(:unique_token, :string)
    field(:error_message, :string)

    field(:key_id, :string)
    field(:aes256_key, :string)
    field(:init_vector, :string)
    field(:payload, :string)
  end

  def new(request_type, request_params) do
    changeset(
      %Gofer.Deployment.Model.Deployment.EncryptedSecret{},
      Map.put(request_params, :request_type, request_type)
    )
  end

  def with_error(metadata, message) when is_binary(message) do
    changeset(metadata, %{error_message: message})
  end

  def with_error(metadata, reason) do
    changeset(metadata, %{error_message: "#{inspect(reason)}"})
  end

  def changeset(metadata, params) do
    metadata
    |> Ecto.Changeset.cast(params, @all_fields)
    |> Ecto.Changeset.validate_required(@required_fields)
    |> validate_payload()
  end

  defp validate_payload(changeset = %Ecto.Changeset{valid?: true}) do
    validate_payload(changeset, Ecto.Changeset.get_field(changeset, :request_type))
  end

  defp validate_payload(changeset = %Ecto.Changeset{valid?: false}), do: changeset

  defp validate_payload(changeset, :create),
    do: Ecto.Changeset.validate_required(changeset, @encrypted_secret_fields)

  defp validate_payload(changeset, :update),
    do: Ecto.Changeset.validate_required(changeset, @encrypted_secret_fields)

  defp validate_payload(changeset, :delete),
    do: changeset
end
