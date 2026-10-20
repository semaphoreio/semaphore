defmodule Secrethub.Model.EnvVar do
  @moduledoc """
  Schema model for secret environment variable
  """
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field :name, :string
    field :value, :string
  end

  def changeset(env_var, params) do
    env_var
    |> Ecto.Changeset.cast(params, [:name, :value])
    |> Ecto.Changeset.validate_required([:name, :value])
    |> validate_env_var_name()
  end

  defp validate_env_var_name(changeset) do
    name = Ecto.Changeset.get_field(changeset, :name) || ""

    cond do
      not EnvVarPolicy.valid_name?(name) ->
        Ecto.Changeset.add_error(changeset, :name, "of enviorment variable is invalid")

      EnvVarPolicy.reserved?(name) ->
        Ecto.Changeset.add_error(
          changeset,
          :name,
          "#{name} is reserved for Semaphore. To use a different value, export it in " <>
            "the job commands instead; see Reserved variables in the environment " <>
            "variables reference"
        )

      true ->
        changeset
    end
  end
end
