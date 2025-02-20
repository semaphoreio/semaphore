defmodule Gofer.Deployment.Model.Deployment.SubjectRule do
  @moduledoc """
  Holds deployment restriction for users, roles & other entities
  """
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field(:type, Ecto.Enum, values: [:ANY, :AUTO, :USER, :ROLE, :GROUP])
    field(:subject_id, :string)
  end

  def changeset(rule, params) do
    rule
    |> Ecto.Changeset.cast(params, ~w(type subject_id)a)
    |> Ecto.Changeset.validate_required([:type])
    |> maybe_validate_subject_id()
  end

  defp maybe_validate_subject_id(changeset = %Ecto.Changeset{valid?: false}),
    do: changeset

  defp maybe_validate_subject_id(changeset = %Ecto.Changeset{valid?: true}) do
    changeset
    |> Ecto.Changeset.get_field(:type)
    |> validate_subject_id(changeset)
  end

  defp validate_subject_id(:ANY, changeset = %Ecto.Changeset{}), do: changeset
  defp validate_subject_id(:AUTO, changeset = %Ecto.Changeset{}), do: changeset

  defp validate_subject_id(:USER, changeset = %Ecto.Changeset{}),
    do: Ecto.Changeset.validate_required(changeset, [:subject_id])

  defp validate_subject_id(:ROLE, changeset = %Ecto.Changeset{}),
    do: Ecto.Changeset.validate_required(changeset, [:subject_id])

  defp validate_subject_id(:GROUP, changeset = %Ecto.Changeset{}),
    do: Ecto.Changeset.validate_required(changeset, [:subject_id])
end
