defmodule Zebra.Models.Debug do
  use Ecto.Schema

  alias Zebra.LegacyRepo

  import Ecto.Changeset

  require Ecto.Query
  alias Ecto.Query, as: Q

  require Logger

  def type_job, do: "job"
  def type_project, do: "project"

  def valid_types,
    do: [
      type_job(),
      type_project()
    ]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "debugs" do
    belongs_to(:job, Zebra.Models.Job, foreign_key: :job_id)

    field(:debugged_id, :binary_id)
    field(:debugged_type, :string)
    field(:user_id, :binary_id)
  end

  def create(job_id, debugged_type, debugged_id, user_id) do
    params = %{
      job_id: job_id,
      debugged_type: debugged_type,
      debugged_id: debugged_id,
      user_id: user_id
    }

    changeset(%__MODULE__{}, params) |> LegacyRepo.insert()
  end

  ##
  ## Scopes
  ##

  def from_jobs(query \\ __MODULE__) do
    query |> Q.where([j], j.debugged_type == ^type_job())
  end

  ##
  ## Lookup
  ##

  def find_by_job_id(query \\ __MODULE__, job_id) do
    debug = query |> Q.where(job_id: ^job_id) |> Zebra.LegacyRepo.one()

    if debug do
      {:ok, debug}
    else
      {:error, :not_found}
    end
  end

  ##
  ## Helpers
  ##

  def changeset(debug, params \\ %{}) do
    debug
    |> cast(params, [
      :job_id,
      :debugged_type,
      :debugged_id,
      :user_id
    ])
    |> validate_required([:job_id, :debugged_id, :debugged_type, :user_id])
    |> validate_inclusion(:debugged_type, valid_types())
  end
end
