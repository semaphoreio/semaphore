defmodule PreFlightChecks.OrganizationPFC.Model.OrganizationPFC do
  @moduledoc """
  Organization pre-flight check schema

  Contains identifiers of organization and the last requester,
  as well as a definition of pre-flight checks internal specifics.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias PreFlightChecks.OrganizationPFC.Model.OrganizationPFC

  @type t :: %__MODULE__{
          id: String.t(),
          organization_id: String.t(),
          definition: OrganizationPFC.Definition.t(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @fields ~w(organization_id requester_id)a
  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @timestamps_opts type: :utc_datetime

  schema "organization_pre_flight_checks" do
    field :organization_id, :string
    field :requester_id, :string
    embeds_one :definition, OrganizationPFC.Definition

    timestamps()
  end

  @doc false
  def changeset(schema, params) do
    schema
    |> cast(params, @fields)
    |> cast_embed(:definition)
    |> validate_required(:organization_id)
    |> validate_required(:requester_id)
  end
end

defmodule PreFlightChecks.OrganizationPFC.Model.OrganizationPFC.Definition do
  @moduledoc """
  Organization pre-flight check definition schema

  Contains commands to be run in the initialization job
  and secrets to be used by those commands.
  Commands cannot be an empty collection.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          commands: [String.t()],
          secrets: [String.t()]
        }

  @primary_key false
  @fields ~w(commands secrets)a

  embedded_schema do
    field :commands, {:array, :string}
    field :secrets, {:array, :string}
  end

  @doc false
  def changeset(schema, params) do
    schema
    |> cast(params, @fields)
    |> validate_length(:commands, min: 1)
  end
end
