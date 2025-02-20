defmodule Ppl.PplTraces.Model.PplTraces do
  @moduledoc """
  Pipeline Trace type
  It is used to track times when pipeline transitioned to each new state.
  """

  use Ecto.Schema

  import Ecto.Changeset
  alias Ppl.PplRequests.Model.PplRequests

  schema "pipeline_traces" do
    belongs_to :pipeline_requests, PplRequests, [type: Ecto.UUID, foreign_key: :ppl_id]
    field :created_at, :utc_datetime_usec
    field :pending_at, :utc_datetime_usec
    field :queuing_at, :utc_datetime_usec
    field :running_at, :utc_datetime_usec
    field :stopping_at, :utc_datetime_usec
    field :done_at, :utc_datetime_usec

    timestamps(type: :naive_datetime_usec)
  end

  @required_fields_insert ~w(ppl_id created_at)a

  @doc ~S"""
  ## Examples:

      iex> alias Ppl.PplTraces.Model.PplTraces
      iex> PplTraces.changeset_insert(%PplTraces{}) |> Map.get(:valid?)
      false

      iex> alias Ppl.PplTraces.Model.PplTraces
      iex> params = %{ppl_id: UUID.uuid1, created_at: DateTime.utc_now()}
      iex> PplTraces.changeset_insert(%PplTraces{}, params) |> Map.get(:valid?)
      true

  """

  def changeset_insert(ppl_trace, params \\ %{}) do
    ppl_trace
    |> cast(params, @required_fields_insert)
    |> validate_required(@required_fields_insert)
    # this unique_constraint references unique_index in migration
    |> unique_constraint(:one_ppl_trace_per_ppl, name: :one_ppl_trace_per_ppl)
  end
end
