defmodule Front.Models.EphemeralEnvironment do
  @moduledoc """
  Model representing an Ephemeral Environment Type
  """

  require Logger

  alias InternalApi.EphemeralEnvironments.{EphemeralEnvironmentType, TypeState}

  @type state :: :unspecified | :draft | :ready | :cordoned | :deleted

  @type t :: %__MODULE__{
          id: String.t(),
          org_id: String.t(),
          name: String.t(),
          description: String.t(),
          created_by: String.t(),
          last_updated_by: String.t(),
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          state: state(),
          max_number_of_instances: integer(),
          stages: list(map()),
          environment_context: list(map()),
          accessible_project_ids: list(String.t()),
          ttl_config: map() | nil
        }

  defstruct [
    :id,
    :org_id,
    :name,
    :description,
    :created_by,
    :last_updated_by,
    :created_at,
    :updated_at,
    :state,
    :max_number_of_instances,
    :stages,
    :environment_context,
    :accessible_project_ids,
    :ttl_config
  ]

  def list(org_id, project_id) do
    with {:ok, environment_types} <- Front.EphemeralEnvironments.list(org_id, project_id),
         environments <- Enum.map(environment_types, &from_proto/1) do
      {:ok, environments}
    else
      error ->
        Logger.error("Failed to list ephemeral environments: #{inspect(error)}")
        {:error, "Failed to list ephemeral environments"}
    end
  end

  def get(environment_id, org_id) do
    with {:ok, environment_type} <- Front.EphemeralEnvironments.describe(environment_id, org_id),
         environment <- from_proto(environment_type) do
      {:ok, environment}
    else
      error ->
        Logger.error("Failed to get ephemeral environment: #{inspect(error)}")
        {:error, "Failed to get ephemeral environment"}
    end
  end

  @spec create(String.t(), String.t(), map()) ::
          {:error, String.t()} | {:ok, Front.Models.EphemeralEnvironment.t()}
  def create(org_id, user_id, params) do
    environment_type = %EphemeralEnvironmentType{
      id: Ecto.UUID.generate(),
      org_id: org_id,
      name: params["name"] || "",
      description: params["description"] || "",
      created_by: user_id,
      last_updated_by: user_id,
      created_at: now_proto_timestamp(),
      updated_at: now_proto_timestamp(),
      state: TypeState.value(:TYPE_STATE_DRAFT),
      max_number_of_instances: params["max_instances"] || 1,
      stages: map_stages_from_params(params["stages"]),
      environment_context: map_environment_context_from_params(params["environment_context"]),
      accessible_project_ids: params["accessible_project_ids"] || [],
      ttl_config: map_ttl_config_from_params(params["ttl_config"])
    }

    with {:ok, created_type} <- Front.EphemeralEnvironments.create(environment_type),
         environment <- from_proto(created_type) do
      {:ok, environment}
    else
      error ->
        Logger.error("Failed to create ephemeral environment: #{inspect(error)}")
        {:error, "Failed to create ephemeral environment"}
    end
  end

  def delete(id, org_id) do
    Front.EphemeralEnvironments.delete(id, org_id)
    |> case do
      :ok ->
        :ok

      error ->
        Logger.error("Failed to delete ephemeral environment: #{inspect(error)}")
        {:error, "Failed to delete ephemeral environment"}
    end
  end

  def cordon(id, org_id) do
    with {:ok, cordoned_type} <- Front.EphemeralEnvironments.cordon(id, org_id),
         environment <- from_proto(cordoned_type) do
      {:ok, environment}
    else
      error ->
        Logger.error("Failed to cordon ephemeral environment: #{inspect(error)}")
        {:error, "Failed to cordon ephemeral environment"}
    end
  end

  @spec update(String.t(), String.t(), map()) ::
          {:error, String.t()} | {:ok, Front.Models.EphemeralEnvironment.t()}
  def update(id, org_id, params) do
    environment_type = %EphemeralEnvironmentType{
      id: id,
      org_id: org_id,
      name: params["name"] || "",
      description: params["description"] || "",
      max_number_of_instances: params["max_instances"] || 1,
      stages: map_stages_from_params(params["stages"]),
      environment_context: map_environment_context_from_params(params["environment_context"]),
      accessible_project_ids: params["accessible_project_ids"] || [],
      ttl_config: map_ttl_config_from_params(params["ttl_config"])
    }

    with {:ok, updated_type} <- Front.EphemeralEnvironments.update(environment_type),
         environment <- from_proto(updated_type) do
      {:ok, environment}
    else
      error ->
        Logger.error("Failed to update ephemeral environment: #{inspect(error)}")
        {:error, "Failed to update ephemeral environment"}
    end
  end

  @doc """
  Creates a new EphemeralEnvironment struct from protobuf data
  """
  @spec from_proto(EphemeralEnvironmentType.t()) :: t
  def from_proto(proto) do
    %__MODULE__{
      id: proto.id,
      org_id: proto.org_id,
      name: proto.name,
      description: proto.description,
      created_by: proto.created_by,
      last_updated_by: proto.last_updated_by,
      created_at: timestamp_to_datetime(proto.created_at),
      updated_at: timestamp_to_datetime(proto.updated_at),
      state: parse_state(proto.state),
      max_number_of_instances: proto.max_number_of_instances,
      stages: map_stages_from_proto(proto.stages, proto.org_id),
      environment_context: map_environment_context_from_proto(proto.environment_context),
      accessible_project_ids: proto.accessible_project_ids || [],
      ttl_config: map_ttl_config_from_proto(proto.ttl_config)
    }
  end

  defp map_stages_from_proto(nil, _org_id), do: []

  defp map_stages_from_proto(stages, org_id) do
    alias InternalApi.EphemeralEnvironments.StageType

    # Collect all project IDs from pipelines
    project_ids =
      stages
      |> Enum.map(fn stage -> stage.pipeline && stage.pipeline.project_id end)
      |> Enum.filter(&(&1 != nil && &1 != ""))
      |> Enum.uniq()

    # Collect all subject IDs from RBAC rules
    subject_ids =
      stages
      |> Enum.flat_map(fn stage -> stage.rbac_rules || [] end)
      |> Enum.map(fn rule -> rule.subject_id end)
      |> Enum.filter(&(&1 != nil && &1 != ""))
      |> Enum.uniq()

    # Fetch all projects at once
    projects = Front.Models.Project.find_many_by_ids(project_ids, org_id)
    projects_map = Map.new(projects, fn project -> {project.id, project} end)

    # Fetch all subjects at once
    subjects_map =
      case Front.RBAC.Subjects.list_subjects(org_id, subject_ids) do
        {:ok, subjects} -> subjects
        {:error, _} -> %{}
      end

    Enum.map(stages, fn stage ->
      %{
        id:
          case StageType.key(stage.type) do
            :STAGE_TYPE_PROVISION -> "provisioning"
            :STAGE_TYPE_DEPLOY -> "deployment"
            :STAGE_TYPE_DEPROVISION -> "deprovisioning"
            _ -> "unknown"
          end,
        name:
          case StageType.key(stage.type) do
            :STAGE_TYPE_PROVISION -> "Provisioning"
            :STAGE_TYPE_DEPLOY -> "Deployment"
            :STAGE_TYPE_DEPROVISION -> "Deprovisioning"
            _ -> "Unknown"
          end,
        pipeline: map_pipeline_from_proto(stage.pipeline, projects_map),
        parameters: map_parameters_from_proto(stage.parameters),
        rbacAccess: map_rbac_rules_from_proto(stage.rbac_rules, subjects_map)
      }
    end)
  end

  defp map_pipeline_from_proto(nil, _projects_map),
    do: %{
      projectId: "",
      projectName: "",
      projectDescription: nil,
      branch: "",
      pipelineYamlFile: ""
    }

  defp map_pipeline_from_proto(pipeline, projects_map) do
    project_id = pipeline.project_id || ""
    project = Map.get(projects_map, project_id)

    %{
      projectId: project_id,
      projectName: if(project, do: project.name, else: project_id),
      projectDescription: if(project, do: project.description, else: nil),
      branch: pipeline.branch || "",
      pipelineYamlFile: pipeline.pipeline_yaml_file || ""
    }
  end

  defp map_parameters_from_proto(nil), do: []

  defp map_parameters_from_proto(parameters) do
    Enum.map(parameters, fn param ->
      %{
        name: param.name,
        description: param.description,
        required: param.required
      }
    end)
  end

  defp map_rbac_rules_from_proto(nil, _subjects_map), do: []

  defp map_rbac_rules_from_proto(rbac_rules, subjects_map) do
    alias InternalApi.RBAC.SubjectType

    Enum.map(rbac_rules, fn rule ->
      subject = Map.get(subjects_map, rule.subject_id)

      %{
        type:
          case SubjectType.key(rule.subject_type) do
            :USER -> "user"
            :GROUP -> "group"
            :SERVICE_ACCOUNT -> "service_account"
            _ -> "unknown"
          end,
        id: rule.subject_id,
        name: if(subject, do: subject.display_name, else: rule.subject_id)
      }
    end)
  end

  defp map_environment_context_from_proto(nil), do: []

  defp map_environment_context_from_proto(context) do
    Enum.map(context, fn ctx ->
      %{
        name: ctx.name,
        description: ctx.description
      }
    end)
  end

  defp map_ttl_config_from_proto(nil), do: %{default_ttl_hours: nil, allow_extension: false}

  defp map_ttl_config_from_proto(ttl_config) do
    %{
      default_ttl_hours: ttl_config.duration_hours,
      allow_extension: ttl_config.allow_extension
    }
  end

  @spec parse_state(integer() | nil) :: state()
  defp parse_state(nil), do: :unspecified

  defp parse_state(state_value) do
    state_value
    |> TypeState.key()
    |> case do
      :TYPE_STATE_DRAFT -> :draft
      :TYPE_STATE_READY -> :ready
      :TYPE_STATE_CORDONED -> :cordoned
      :TYPE_STATE_DELETED -> :deleted
      _ -> :unspecified
    end
  end

  @spec state_to_proto(state()) :: integer()
  def state_to_proto(state) do
    case state do
      :draft -> TypeState.value(:TYPE_STATE_DRAFT)
      :ready -> TypeState.value(:TYPE_STATE_READY)
      :cordoned -> TypeState.value(:TYPE_STATE_CORDONED)
      :deleted -> TypeState.value(:TYPE_STATE_DELETED)
      _ -> TypeState.value(:TYPE_STATE_UNSPECIFIED)
    end
  end

  defp timestamp_to_datetime(%Google.Protobuf.Timestamp{seconds: seconds}) do
    DateTime.from_unix!(seconds)
  end

  defp timestamp_to_datetime(_), do: DateTime.utc_now()

  defp now_proto_timestamp do
    seconds = DateTime.utc_now() |> DateTime.to_unix()
    Google.Protobuf.Timestamp.new(seconds: seconds)
  end

  # Mapping functions from params to protobuf structs
  defp map_stages_from_params(stages) when is_list(stages) do
    alias InternalApi.EphemeralEnvironments.StageConfig

    Enum.map(stages, fn stage ->
      %StageConfig{
        type: map_stage_type_from_string(stage["id"]),
        pipeline: map_pipeline_from_params(stage["pipeline"]),
        parameters: map_parameters_from_params(stage["parameters"]),
        rbac_rules: map_rbac_rules_from_params(stage["rbacAccess"])
      }
    end)
  end

  defp map_stages_from_params(_), do: []

  defp map_stage_type_from_string("provisioning"),
    do: InternalApi.EphemeralEnvironments.StageType.value(:STAGE_TYPE_PROVISION)

  defp map_stage_type_from_string("deployment"),
    do: InternalApi.EphemeralEnvironments.StageType.value(:STAGE_TYPE_DEPLOY)

  defp map_stage_type_from_string("deprovisioning"),
    do: InternalApi.EphemeralEnvironments.StageType.value(:STAGE_TYPE_DEPROVISION)

  defp map_stage_type_from_string(_),
    do: InternalApi.EphemeralEnvironments.StageType.value(:STAGE_TYPE_UNSPECIFIED)

  defp map_pipeline_from_params(nil), do: %InternalApi.EphemeralEnvironments.PipelineConfig{}

  defp map_pipeline_from_params(pipeline) do
    %InternalApi.EphemeralEnvironments.PipelineConfig{
      project_id: pipeline["projectId"] || "",
      branch: pipeline["branch"] || "",
      pipeline_yaml_file: pipeline["pipelineYamlFile"] || ""
    }
  end

  defp map_parameters_from_params(nil), do: []

  defp map_parameters_from_params(parameters) when is_list(parameters) do
    Enum.map(parameters, fn param ->
      %InternalApi.EphemeralEnvironments.StageParameter{
        name: param["name"] || "",
        description: param["description"] || "",
        required: param["required"] || false
      }
    end)
  end

  defp map_parameters_from_params(_), do: []

  defp map_rbac_rules_from_params(nil), do: []

  defp map_rbac_rules_from_params(rbac_access) when is_list(rbac_access) do
    Enum.map(rbac_access, fn rule ->
      %InternalApi.EphemeralEnvironments.RBACRule{
        subject_type: map_rbac_type_from_string(rule["type"]),
        subject_id: rule["id"] || ""
      }
    end)
  end

  defp map_rbac_rules_from_params(_), do: []

  defp map_rbac_type_from_string("user"), do: InternalApi.RBAC.SubjectType.value(:USER)
  defp map_rbac_type_from_string("group"), do: InternalApi.RBAC.SubjectType.value(:GROUP)

  defp map_rbac_type_from_string("service_account"),
    do: InternalApi.RBAC.SubjectType.value(:SERVICE_ACCOUNT)

  defp map_rbac_type_from_string(_), do: 0

  defp map_environment_context_from_params(nil), do: []

  defp map_environment_context_from_params(context) when is_list(context) do
    Enum.map(context, fn ctx ->
      %InternalApi.EphemeralEnvironments.EnvironmentContext{
        name: ctx["name"],
        description: ctx["description"]
      }
    end)
  end

  defp map_environment_context_from_params(_), do: []

  defp map_ttl_config_from_params(nil), do: nil

  defp map_ttl_config_from_params(ttl_config) do
    %InternalApi.EphemeralEnvironments.TTLConfig{
      duration_hours: ttl_config["default_ttl_hours"] || 0,
      allow_extension: ttl_config["allow_extension"] || false
    }
  end
end
