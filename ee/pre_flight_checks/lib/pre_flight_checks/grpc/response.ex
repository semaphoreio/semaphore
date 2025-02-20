defmodule PreFlightChecks.GRPC.Response do
  @moduledoc """
  gRPC response utility functions
  """
  alias PreFlightChecks.OrganizationPFC.Model.OrganizationPFC
  alias PreFlightChecks.ProjectPFC.Model.ProjectPFC
  alias InternalApi.PreFlightChecksHub, as: API

  @typedoc """
  gRPC response type
  """
  @type t() ::
          API.DescribeResponse.t()
          | API.ApplyResponse.t()
          | API.DestroyResponse.t()

  @typedoc """
  gRPC proto struct
  """
  @type proto() ::
          API.DescribeResponse
          | API.ApplyResponse
          | API.DestroyResponse

  @typedoc """
  Pre-flight check
  """
  @type pfc() :: OrganizationPFC.t() | ProjectPFC.t()

  @typedoc """
  Pre-flight check's entity (organization or project)
  """
  @type entity() :: :organization | :project

  @doc """
  Returns successful response with pre-flight checks
  """
  @spec success(proto(), keyword(pfc())) :: t()
  def success(response_module, pre_flight_checks) do
    response_module.new(
      status: InternalApi.Status.new(code: :OK),
      pre_flight_checks:
        API.PreFlightChecks.new(
          organization_pfc: to_response_format(pre_flight_checks[:org_pfc]),
          project_pfc: to_response_format(pre_flight_checks[:proj_pfc])
        )
    )
  end

  @doc """
  Returns invalid argument response with error message
  """
  @spec invalid_argument(proto(), Ecto.Changeset.t() | binary()) :: t()
  def invalid_argument(response_module, %Ecto.Changeset{} = changeset) do
    response_module.new(
      status:
        InternalApi.Status.new(
          code: :INVALID_ARGUMENT,
          message: message_from_changeset(changeset)
        )
    )
  end

  def invalid_argument(response_module, message) when is_binary(message) do
    response_module.new(
      status:
        InternalApi.Status.new(
          code: :INVALID_ARGUMENT,
          message: message
        )
    )
  end

  @doc """
  Returns invalid argument response with error message
  """
  @spec not_found(proto(), entity(), binary()) :: t()
  def not_found(response_module, entity, entity_id) do
    message = "Pre-flight check for #{entity} \"#{entity_id}\" was not found"

    response_module.new(
      status:
        InternalApi.Status.new(
          code: :NOT_FOUND,
          message: message
        )
    )
  end

  #
  # Protobuf formatters
  #

  defp to_response_format(%OrganizationPFC{definition: definition} = pfc) do
    API.OrganizationPFC.new(
      commands: definition.commands,
      secrets: definition.secrets,
      requester_id: pfc.requester_id,
      created_at: to_response_format(pfc.inserted_at),
      updated_at: to_response_format(pfc.updated_at)
    )
  end

  defp to_response_format(%ProjectPFC{definition: definition} = pfc) do
    API.ProjectPFC.new(
      commands: definition.commands,
      secrets: definition.secrets,
      requester_id: pfc.requester_id,
      created_at: to_response_format(pfc.inserted_at),
      updated_at: to_response_format(pfc.updated_at),
      agent: to_response_format(definition.agent)
    )
  end

  defp to_response_format(%ProjectPFC.Definition.Agent{} = agent) do
    API.Agent.new(
      machine_type: agent.machine_type,
      os_image: agent.os_image
    )
  end

  defp to_response_format(%DateTime{} = dt) do
    Google.Protobuf.Timestamp.new(
      seconds: DateTime.to_unix(dt),
      nanos: elem(dt.microsecond, 0) * 1000
    )
  end

  defp to_response_format(nil), do: nil

  #
  # Ecto error handling
  #

  @error_priority_list ~w(
    organization_id project_id requester_id
    commands machine_type os_image
  )a

  defp message_from_changeset(%Ecto.Changeset{} = changeset) do
    changeset
    |> traverse_errors()
    |> select_top_error()
  end

  defp traverse_errors(changeset) do
    errors = Ecto.Changeset.traverse_errors(changeset, &message_from_error/1)
    definition_errors = errors |> Map.get(:definition, %{}) |> Map.new()
    agent_errors = definition_errors |> Map.get(:agent, %{}) |> Map.new()

    errors
    |> Map.drop([:definition])
    |> Map.merge(definition_errors)
    |> Map.drop([:agent])
    |> Map.merge(agent_errors)
  end

  defp message_from_error({msg, opts}) do
    Enum.reduce(opts, msg, &String.replace(&2, "%{#{elem(&1, 0)}}", to_string(elem(&1, 1))))
  end

  defp select_top_error(errors) do
    Enum.reduce_while(@error_priority_list, errors, fn key, _ ->
      case errors do
        %{^key => msg} -> {:halt, "#{key} #{msg}"}
        _no_key -> {:cont, errors}
      end
    end)
  end
end
