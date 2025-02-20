defmodule InternalClients.SelfHostedHub.RequestFormatter do
  @moduledoc """
  Module serves to format data received from API client via HTTP into protobuf
  messages suitable for gRPC communication with SelHostedHub service.
  """

  alias PublicAPI.Util.ToTuple

  alias InternalApi.SelfHosted.{
    CreateRequest,
    UpdateRequest,
    DescribeRequest,
    DescribeAgentRequest,
    DisableAllAgentsRequest,
    DeleteAgentTypeRequest,
    ListKeysetRequest,
    ListAgentsRequest,
    AgentNameSettings,
    AgentType
  }

  import InternalClients.Common

  @on_load :load_atoms

  defp load_atoms() do
    [
      InternalApi.SelfHosted.AgentNameSettings.AssignmentOrigin
    ]
    |> Enum.each(&Code.ensure_loaded/1)
  end

  # Create

  def form_create_request(params) when is_map(params) do
    %CreateRequest{
      organization_id: from_params!(params, :organization_id),
      name: from_params!(params.spec, :name),
      requester_id: from_params!(params, :requester_id),
      agent_name_settings: agent_name_settings(params.spec)
    }
    |> ToTuple.ok()
  rescue
    error -> error
  end

  def form_create_request(_), do: ToTuple.internal_error("Internal error")

  def form_update_request(params) when is_map(params) do
    %UpdateRequest{
      organization_id: from_params!(params, :organization_id),
      name: from_params!(params, :agent_type_name),
      requester_id: from_params!(params, :requester_id),
      agent_type: agent_type(params)
    }
    |> ToTuple.ok()
  rescue
    error -> error
  end

  def form_update_request(_), do: ToTuple.internal_error("Internal error")

  # Describe

  def form_describe_request(params) when is_map(params) do
    %DescribeRequest{
      organization_id: from_params!(params, :organization_id),
      name: from_params(params, :agent_type_name, "")
    }
    |> ToTuple.ok()
  rescue
    error -> error
  end

  def form_describe_request(_), do: ToTuple.internal_error("Internal error")

  # Describe agent

  def form_describe_agent_request(params) when is_map(params) do
    %DescribeAgentRequest{
      organization_id: from_params!(params, :organization_id),
      name: from_params!(params, :agent_name)
    }
    |> ToTuple.ok()
  rescue
    error -> error
  end

  def form_describe_agent_request(_), do: ToTuple.internal_error("Internal error")

  # Delete

  def form_delete_request(params) when is_map(params) do
    %DeleteAgentTypeRequest{
      organization_id: from_params!(params, :organization_id),
      name: from_params!(params, :agent_type_name)
    }
    |> ToTuple.ok()
  rescue
    error -> error
  end

  def form_delete_request(_), do: ToTuple.internal_error("Internal error")

  def form_disable_all_request(params) when is_map(params) do
    %DisableAllAgentsRequest{
      organization_id: from_params!(params, :organization_id),
      agent_type: from_params!(params, :agent_type_name),
      only_idle: from_params(params, :only_idle, true)
    }
    |> ToTuple.ok()
  rescue
    error -> error
  end

  def form_disable_all_request(_), do: ToTuple.internal_error("Internal error")

  # List

  def form_list_request(params) when is_map(params) do
    %ListKeysetRequest{
      organization_id: from_params!(params, :organization_id),
      cursor: from_params(params, :page_token, ""),
      page_size: from_params(params, :page_size, 20)
    }
    |> ToTuple.ok()
  rescue
    error -> error
  end

  def form_list_request(_), do: ToTuple.internal_error("Internal error")

  # List agents

  def form_list_agents_request(params) when is_map(params) do
    %ListAgentsRequest{
      organization_id: from_params!(params, :organization_id),
      agent_type_name: from_params(params, :agent_type, ""),
      page_size: from_params(params, :page_size, 20),
      cursor: from_params(params, :page_token, "")
    }
    |> ToTuple.ok()
  rescue
    error -> error
  end

  def form_list_agents_request(_), do: ToTuple.internal_error("Internal error")

  defp agent_name_settings(%{
         agent_name_settings:
           agent_name_settings = %{assignment_origin: "ASSIGNMENT_ORIGIN_AWS_STS", aws: aws}
       })
       when is_map(aws) do
    %AgentNameSettings{
      assignment_origin:
        String.to_existing_atom(from_params!(agent_name_settings, :assignment_origin)),
      release_after: from_params(agent_name_settings, :release_after),
      aws: %AgentNameSettings.AWS{
        account_id: from_params!(aws, :account_id),
        role_name_patterns: from_params!(aws, :role_name_patterns)
      }
    }
  end

  defp agent_name_settings(%{agent_name_settings: agent_name_settings}) do
    %AgentNameSettings{
      assignment_origin:
        String.to_existing_atom(from_params!(agent_name_settings, :assignment_origin)),
      release_after: from_params(agent_name_settings, :release_after)
    }
  end

  defp agent_type(params) do
    %AgentType{
      organization_id: from_params!(params, :organization_id),
      name: from_params!(params.spec, :name),
      agent_name_settings: agent_name_settings(params.spec)
    }
  end
end
