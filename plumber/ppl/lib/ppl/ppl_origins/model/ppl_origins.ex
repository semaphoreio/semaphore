defmodule Ppl.PplOrigins.Model.PplOrigins do
  @moduledoc """
  PplOrigin type
  Serves to store original request and yaml definition of pipeline before any revisions.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Ppl.PplRequests.Model.PplRequests


  schema "pipeline_origins" do
    belongs_to :pipeline_requests, PplRequests, [type: Ecto.UUID, foreign_key: :ppl_id]
    field :initial_request, :map
    field :initial_definition, :string

    timestamps(type: :naive_datetime_usec)
  end

  @required_fields ~w(ppl_id initial_request)a
  @required_fields_def ~w(initial_definition)a

  @doc ~S"""
  ## Examples:

      iex> alias Ppl.PplOrigins.Model.PplOrigins
      iex> PplOrigins.changeset(%PplOrigins{}) |> Map.get(:valid?)
      false

      iex> alias Ppl.PplOrigins.Model.PplOrigins
      iex> params = %{ppl_id: UUID.uuid1, initial_request: %{"service" => "local",
      ...>                                                  "repo_name" => "2_basic"}}
      iex> PplOrigins.changeset(%PplOrigins{}, params) |> Map.get(:valid?)
      true

  """
  def changeset(ppl_or, params \\ %{}) do
    ppl_or
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
    # this unique_constraint references unique_index in migration
    |> unique_constraint(:one_origin_per_ppl, name: :one_origin_per_ppl)
  end

  @doc ~S"""
  ## Examples:

      iex> alias Ppl.PplOrigins.Model.PplOrigins
      iex> PplOrigins.changeset_definition(%PplOrigins{}) |> Map.get(:valid?)
      false

      iex> alias Ppl.PplOrigins.Model.PplOrigins
      iex> params = %{initial_definition: "Yaml definition string"}
      iex> PplOrigins.changeset_definition(%PplOrigins{}, params) |> Map.get(:valid?)
      true

  """
  def changeset_definition(ppl_or, params \\ %{}) do
    ppl_or
    |> cast(params, @required_fields_def)
    |> validate_required(@required_fields_def)
  end
end
