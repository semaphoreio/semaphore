defmodule Scheduler.DeleteRequests.Model.DeleteRequests do
  @moduledoc """
  DeleteRequests type

  Each time periodic's deletion is requested the request is persisted in DB for
  audit purposes.
  """

  use Ecto.Schema

  import Ecto.Changeset
  @timestamps_opts [type: :naive_datetime_usec]
  schema "delete_requests" do
    field :periodic_id, :string, read_after_writes: true
    field :periodic_name, :string, read_after_writes: true
    field :organization_id, :string, read_after_writes: true
    field :requester, :string

    timestamps()
  end

  @required_fields ~w(requester)a
  @optional_fields ~w(periodic_id periodic_name organization_id)a

  @doc ~S"""
  ## Examples:

      iex> alias Scheduler.DeleteRequests.Model.DeleteRequests
      iex> DeleteRequests.changeset(%DeleteRequests{}) |> Map.get(:valid?)
      false

      iex> alias Scheduler.DeleteRequests.Model.DeleteRequests
      iex> params = %{requester: UUID.uuid1(), organization_id: UUID.uuid1(),
      ...>           periodic_name: "P1", periodic_id: UUID.uuid1()}
      iex> DeleteRequests.changeset(%DeleteRequests{}, params) |> Map.get(:valid?)
      true
  """
  def changeset(periodic, params \\ %{}) do
    periodic
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_id_or_name_org_id_present(params)
  end

  defp validate_id_or_name_org_id_present(changeset, params) do
    if not_empty_string(params[:periodic_id]) or
         (not_empty_string(params[:periodic_name]) and not_empty_string(params[:organization_id])) do
      changeset
    else
      add_error(
        changeset,
        :params,
        "Either periodic_id or periodic_name and organization_id" <>
          " must have a non-empty string value."
      )
    end
  end

  defp not_empty_string(val) when is_binary(val) and val != "", do: true
  defp not_empty_string(_val), do: false
end
