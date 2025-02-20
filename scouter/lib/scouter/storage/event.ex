defmodule Scouter.Storage.Event do
  @moduledoc """
  This module is responsible for defining the Event schema.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "events" do
    field(:organization_id, :string)
    field(:project_id, :string)
    field(:user_id, :string)
    field(:event_id, :string)
    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset based on the `params` map.
  """
  def changeset(event, params) do
    event
    |> cast(params, [:organization_id, :project_id, :user_id, :event_id])
    |> validate_required([:event_id])
    |> validate_context()
  end

  defp validate_context(changeset) do
    organization_id = get_field(changeset, :organization_id)
    project_id = get_field(changeset, :project_id)
    user_id = get_field(changeset, :user_id)

    Enum.any?([organization_id, project_id, user_id], &(&1 != nil && &1 != ""))
    |> case do
      true ->
        changeset

      false ->
        add_error(
          changeset,
          :base,
          "at least one of organization_id, user_id, or project_id must be provided"
        )
    end
  end
end
