defmodule PreFlightChecks.ProjectPFC.Model.ProjectPFC do
  @moduledoc """
  Project pre-flight check schema

  Contains identifiers for organization, project and last requester,
  as well as a definition of pre-flight checks internal specifics.
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias PreFlightChecks.ProjectPFC.Model.ProjectPFC

  @type t :: %__MODULE__{
          id: String.t(),
          organization_id: String.t(),
          project_id: String.t(),
          requester_id: String.t(),
          definition: ProjectPFC.Definition.t(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @fields ~w(organization_id project_id requester_id)a
  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @timestamps_opts type: :utc_datetime

  schema "project_pre_flight_checks" do
    field :organization_id, :string
    field :project_id, :string
    field :requester_id, :string
    embeds_one :definition, ProjectPFC.Definition

    timestamps()
  end

  @doc false
  def changeset(schema, params) do
    schema
    |> cast(params, @fields)
    |> cast_embed(:definition)
    |> validate_required(:organization_id)
    |> validate_required(:project_id)
    |> validate_required(:requester_id)
  end
end

defmodule PreFlightChecks.ProjectPFC.Model.ProjectPFC.Definition do
  @moduledoc """
  Project pre-flight check definition schema

  Contains commands to be run in the initialization job
  and secrets to be used by those commands.
  Commands cannot be an empty collection.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias PreFlightChecks.ProjectPFC.Model.ProjectPFC.Definition

  @primary_key false
  @fields ~w(commands secrets)a

  @type t :: %__MODULE__{
          commands: [String.t()],
          secrets: [String.t()],
          agent: Definition.Agent.t()
        }

  embedded_schema do
    field :commands, {:array, :string}
    field :secrets, {:array, :string}

    embeds_one :agent, Definition.Agent
  end

  @doc false
  def changeset(schema, params) do
    schema
    |> cast(params, @fields)
    |> cast_embed(:agent)
    |> validate_length(:commands, min: 1)
  end
end

defmodule PreFlightChecks.ProjectPFC.Model.ProjectPFC.Definition.Agent do
  @moduledoc """
  Project pre-flight check agent configuration schema

  Contains machine type and OS image used to run the initialization job.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          machine_type: String.t(),
          os_image: String.t()
        }

  @primary_key false
  @fields ~w(machine_type os_image)a

  embedded_schema do
    field :machine_type, :string
    field :os_image, :string
  end

  @doc false
  def changeset(schema, params) do
    schema
    |> cast(params, @fields)
    |> validate_required(:machine_type)
  end
end
