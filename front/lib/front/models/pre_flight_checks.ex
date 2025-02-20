defmodule Front.Models.PreFlightChecks do
  @moduledoc """
  Pre-flight checks API and models
  """

  alias InternalApi.PreFlightChecksHub, as: API

  alias API.PreFlightChecksService.Stub
  alias Front.Models.PreFlightChecks
  require Logger

  defmodule AgentConfig do
    @moduledoc "Agent configuration model schema"
    use Ecto.Schema
    import Ecto.Changeset

    @typedoc """
    Agent configuration type
    """
    @type t() :: %__MODULE__{
            machine_type: String.t(),
            os_image: String.t()
          }

    @fields ~w(machine_type os_image)a
    @primary_key false
    embedded_schema do
      field(:machine_type, :string)
      field(:os_image, :string)
    end

    @doc "Create new struct with default parameters"
    @spec new() :: t()
    def new(params \\ []), do: struct(__MODULE__, init_params(params))

    defp init_params(params),
      do: Map.new(default_params()) |> Map.merge(Map.new(params), &init_param/3)

    @doc "Default struct parameters"
    @spec default_params() :: map()
    def default_params, do: %{machine_type: "", os_image: ""}

    defp init_param(_key, default, provided) do
      if provided, do: provided, else: default
    end

    @doc "Apply changeset to the struct"
    @spec changeset(t(), map()) :: Ecto.Changeset.t(t())
    def changeset(schema, params) do
      schema
      |> cast(params, @fields, empty_values: [])
      |> validate_required(:machine_type)
    end

    @doc "Maps Protobuf API content to model (from response)"
    @spec from_api(map() | nil) :: t()
    def from_api(agent) when is_map(agent), do: new(agent)
    def from_api(agent) when is_nil(agent), do: new()

    @doc "Maps model to API content (for requests)"
    @spec to_api(t()) :: map()
    def to_api(model = %__MODULE__{}), do: Map.from_struct(model)
  end

  defmodule ProjectPFC do
    @moduledoc "Project pre-flight checks model schema"
    use Ecto.Schema
    import Ecto.Changeset

    @typedoc "Project PFC type"
    @type t() :: %__MODULE__{
            commands: [String.t()] | nil,
            secrets: [String.t()] | nil,
            has_custom_agent: boolean(),
            agent: AgentConfig.t() | nil,
            requester_id: String.t() | nil,
            updated_at: DateTime.t() | nil
          }

    @fields ~w(commands secrets has_custom_agent requester_id updated_at)a
    @primary_key false
    embedded_schema do
      field(:commands, {:array, :string})
      field(:secrets, {:array, :string})
      field(:has_custom_agent, :boolean)
      embeds_one(:agent, AgentConfig, on_replace: :delete)

      field(:requester_id, :string)
      field(:updated_at, :utc_datetime)
    end

    defdelegate describe(project_id),
      to: PreFlightChecks,
      as: :describe_for_project

    defdelegate apply(organization_id, project_id, requester_id, model),
      to: PreFlightChecks,
      as: :apply_for_project

    defdelegate destroy(project_id, requester_id),
      to: PreFlightChecks,
      as: :destroy_for_project

    @doc "Create empty struct (without default parameters)"
    @spec empty() :: t()
    def empty, do: struct(__MODULE__)

    @doc "Create new struct with default parameters"
    @spec new() :: t()
    def new(params \\ []), do: struct(__MODULE__, init_params(params))

    defp init_params(params),
      do: Map.new(default_params()) |> Map.merge(Map.new(params), &init_param/3)

    defp init_param(_key, default, provided) do
      if provided, do: provided, else: default
    end

    @doc "Default struct parameters"
    @spec default_params() :: map()
    def default_params,
      do: %{
        commands: [],
        secrets: [],
        has_custom_agent: false,
        agent: AgentConfig.new(),
        requester_id: "",
        updated_at: nil
      }

    @doc "Apply changeset to the struct"
    @spec changeset(t(), map()) :: Ecto.Changeset.t(t())
    def changeset(schema), do: change(schema)

    def changeset(schema, params) do
      schema
      |> cast(escape_params(params), @fields)
      |> cast_embed(:agent)
      |> validate_length(:commands, min: 1)
    end

    defp escape_params(params) do
      params
      |> Map.update("commands", [], &split_lines/1)
    end

    defp split_lines(text),
      do:
        text
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(String.length(&1) < 1))

    @doc "Maps Protobuf API content to model (from response)"
    @spec from_api(map() | nil) :: t()
    def from_api(pfc) when is_map(pfc) do
      pfc
      |> Map.take(~w(commands secrets requester_id)a)
      |> Map.put(:has_custom_agent, not is_nil(pfc.agent))
      |> Map.put(:agent, AgentConfig.from_api(pfc.agent))
      |> Map.put(:updated_at, timestamp_from_api(pfc.updated_at))
      |> new()
    end

    def from_api(pfc) when is_nil(pfc), do: new()

    defp timestamp_from_api(%{seconds: seconds}),
      do: DateTime.from_unix!(seconds)

    defp timestamp_from_api(nil), do: nil

    @doc "Maps model to API content (for requests)"
    @spec to_api(t()) :: map()
    def to_api(model = %__MODULE__{}) do
      model
      |> Map.take(~w(commands secrets has_custom_agent agent)a)
      |> case do
        %{has_custom_agent: true} = params ->
          params |> Map.update(:agent, %{}, &AgentConfig.to_api/1)

        %{has_custom_agent: false} = params ->
          params |> Map.delete(:agent)
      end
      |> Map.delete(:has_custom_agent)
    end
  end

  defmodule OrganizationPFC do
    @moduledoc "Organization pre-flight checks model schema"
    use Ecto.Schema
    import Ecto.Changeset

    @typedoc "Organization PFC type"
    @type t() :: %__MODULE__{
            commands: [String.t()] | nil,
            secrets: [String.t()] | nil,
            requester_id: String.t() | nil,
            updated_at: DateTime.t() | nil
          }

    @fields ~w(commands secrets requester_id updated_at)a
    @primary_key false
    embedded_schema do
      field(:commands, {:array, :string})
      field(:secrets, {:array, :string})

      field(:requester_id, :string)
      field(:updated_at, :utc_datetime)
    end

    defdelegate describe(organization_id),
      to: PreFlightChecks,
      as: :describe_for_organization

    defdelegate apply(organization_id, requester_id, model),
      to: PreFlightChecks,
      as: :apply_for_organization

    defdelegate destroy(organization_id, requester_id),
      to: PreFlightChecks,
      as: :destroy_for_organization

    @doc "Create empty struct (without default parameters)"
    @spec empty() :: t()
    def empty, do: struct(__MODULE__)

    @doc "Create new struct with default parameters"
    @spec new() :: t()
    def new(params \\ []), do: struct(__MODULE__, init_params(params))

    defp init_params(params),
      do: Map.new(default_params()) |> Map.merge(Map.new(params), &init_param/3)

    defp init_param(_key, default, provided) do
      if provided, do: provided, else: default
    end

    @doc "Default struct parameters"
    @spec default_params() :: map()
    def default_params,
      do: %{
        commands: [],
        secrets: [],
        requester_id: "",
        updated_at: nil
      }

    @doc "Apply changeset to the struct"
    @spec changeset(t(), map()) :: Ecto.Changeset.t(t())
    def changeset(schema), do: change(schema)

    def changeset(schema, params) do
      schema
      |> cast(escape_params(params), @fields)
      |> validate_length(:commands, min: 1)
    end

    defp escape_params(params) do
      params
      |> Map.update("commands", [], &split_lines/1)
    end

    defp split_lines(text),
      do:
        text
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(String.length(&1) < 1))

    @doc "Maps Protobuf API content to model (from response)"
    @spec from_api(map() | nil) :: t()
    def from_api(pfc) when is_map(pfc) do
      pfc
      |> Map.take(~w(commands secrets requester_id)a)
      |> Map.put(:updated_at, timestamp_from_api(pfc.updated_at))
      |> new()
    end

    def from_api(pfc) when is_nil(pfc), do: new()

    defp timestamp_from_api(%{seconds: seconds}),
      do: DateTime.from_unix!(seconds)

    defp timestamp_from_api(nil), do: nil

    @doc "Maps model to API content (for requests)"
    @spec to_api(t()) :: map()
    def to_api(model = %__MODULE__{}) do
      model
      |> Map.take(~w(commands secrets)a)
    end
  end

  @doc "Describe pre-flight checks of organization"
  @spec describe_for_organization(String.t()) ::
          {:ok, OrganizationPFC.t()} | {:error, any()}
  def describe_for_organization(organization_id) do
    watch("organization_pfcs.model.describe", fn ->
      call_describe(:ORGANIZATION, organization_id: organization_id)
    end)
  end

  @doc "Describe pre-flight checks of project"
  @spec describe_for_project(String.t()) ::
          {:ok, ProjectPFC.t()} | {:error, any()}
  def describe_for_project(project_id) do
    watch("project_pfcs.model.describe", fn ->
      call_describe(:PROJECT, project_id: project_id)
    end)
  end

  @doc "Apply pre-flight checks for organization"
  @spec apply_for_organization(String.t(), String.t(), OrganizationPFC.t()) ::
          {:ok, OrganizationPFC.t()} | {:error, any()}
  def apply_for_organization(organization_id, requester_id, model) do
    watch("organization_pfcs.model.apply", fn ->
      call_apply(:ORGANIZATION,
        organization_id: organization_id,
        requester_id: requester_id,
        pre_flight_checks: to_api(:ORGANIZATION, model)
      )
    end)
  end

  @doc "Apply pre-flight checks for project"
  @spec apply_for_project(String.t(), String.t(), String.t(), ProjectPFC.t()) ::
          {:ok, ProjectPFC.t()} | {:error, any()}
  def apply_for_project(organization_id, project_id, requester_id, model) do
    watch("project_pfcs.model.apply", fn ->
      call_apply(:PROJECT,
        organization_id: organization_id,
        project_id: project_id,
        requester_id: requester_id,
        pre_flight_checks: to_api(:PROJECT, model)
      )
    end)
  end

  @doc "Destroy pre-flight checks from organization"
  @spec destroy_for_organization(String.t(), String.t()) ::
          :ok | {:error, any()}
  def destroy_for_organization(organization_id, requester_id) do
    watch("organization_pfcs.model.destroy", fn ->
      call_destroy(:ORGANIZATION, organization_id: organization_id, requester_id: requester_id)
    end)
  end

  @doc "Destroy pre-flight checks from project"
  @spec destroy_for_project(String.t(), String.t()) ::
          :ok | {:error, any()}
  def destroy_for_project(project_id, requester_id) do
    watch("project_pfcs.model.destroy", fn ->
      call_destroy(:PROJECT, project_id: project_id, requester_id: requester_id)
    end)
  end

  defp call_describe(level, params) do
    with {:ok, request} <- new_request(API.ApplyRequest, level, params),
         {:ok, response} <- grpc_call(&Stub.describe/2, request) do
      case response.status.code do
        :OK -> {:ok, from_response(response, level)}
        :NOT_FOUND -> {:error, response.status}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp call_apply(level, params) do
    with {:ok, request} <- new_request(API.ApplyRequest, level, params),
         {:ok, response} <- grpc_call(&Stub.apply/2, request) do
      case response.status.code do
        :OK -> {:ok, from_response(response, level)}
        :INVALID_ARGUMENT -> {:error, response.status}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp call_destroy(level, params) do
    with {:ok, request} <- new_request(API.ApplyRequest, level, params),
         {:ok, response} <- grpc_call(&Stub.destroy/2, request) do
      case response.status.code do
        :OK -> :ok
        :INVALID_ARGUMENT -> {:error, response.status}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp from_response(%{pre_flight_checks: %{organization_pfc: pfc}}, :ORGANIZATION),
    do: OrganizationPFC.from_api(pfc)

  defp from_response(%{pre_flight_checks: %{project_pfc: pfc}}, :PROJECT),
    do: ProjectPFC.from_api(pfc)

  defp new_request(request_module, level, params),
    do: Map.new(params) |> Map.put(:level, level) |> Util.Proto.deep_new(request_module)

  defp to_api(:ORGANIZATION, model = %OrganizationPFC{}),
    do: %{organization_pfc: OrganizationPFC.to_api(model)}

  defp to_api(:ORGANIZATION, _model), do: %{organization_pfc: nil}

  defp to_api(:PROJECT, model = %ProjectPFC{}),
    do: %{project_pfc: ProjectPFC.to_api(model)}

  defp to_api(:PROJECT, _model), do: %{project_pfc: nil}

  defp grpc_call(func, request) do
    endpoint = Application.fetch_env!(:front, :pre_flight_checks_grpc_endpoint)

    with {:ok, channel} <- GRPC.Stub.connect(endpoint),
         {:ok, response} <- grpc_send(channel, func, request) do
      Util.Proto.to_map(response)
    else
      {:error, _reason} = error -> error
    end
  end

  defp grpc_send(channel, func, request),
    do: func.(channel, request),
    after: GRPC.Stub.disconnect(channel)

  #
  # Watchman callbacks
  #
  defp watch(prefix_key, request_fn) do
    response = Watchman.benchmark("#{prefix_key}.duration", request_fn)
    Watchman.increment(counted_key(prefix_key, response))
    response
  end

  defp counted_key(prefix, :ok), do: "#{prefix}.success"
  defp counted_key(prefix, {:ok, _}), do: "#{prefix}.success"
  defp counted_key(prefix, {:error, %{code: :NOT_FOUND}}), do: "#{prefix}.success"
  defp counted_key(prefix, {:error, _}), do: "#{prefix}.failure"
end
