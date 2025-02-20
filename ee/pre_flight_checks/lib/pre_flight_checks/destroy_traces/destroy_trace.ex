defmodule PreFlightChecks.DestroyTraces.DestroyTrace do
  @moduledoc """
  Destroy requests or delete events trace schema

  Contains organization and project identifier, requester ID number
  (or event name), request level and status of request.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: String.t(),
          organization_id: String.t(),
          project_id: String.t() | nil,
          requester_id: String.t(),
          level: :ORGANIZATION | :PROJECT,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @fields ~w(organization_id project_id requester_id level status)a
  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @timestamps_opts type: :utc_datetime
  @level_values [ORGANIZATION: 1, PROJECT: 2]
  @status_values [RECEIVED: 1, SUCCESS: 2, FAILURE: 3]

  schema "destroy_request_traces" do
    field :organization_id, :string
    field :project_id, :string
    field :requester_id, :string
    field :level, Ecto.Enum, values: @level_values
    field :status, Ecto.Enum, values: @status_values

    timestamps()
  end

  @doc false
  def changeset(schema, params) do
    schema
    |> cast(params, @fields)
  end
end
