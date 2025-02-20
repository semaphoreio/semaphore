defmodule E2E.Clients.Agent do
  @api_endpoint "api/v1alpha"

  alias E2E.Clients.Common

  @doc """
  Lists agents for an agent type.
  Parameters:
    - agent_type (optional): name of the agent type to filter for
    - page_size (optional): number of agents to return per page (default: 200)
    - cursor (optional): cursor for pagination
  Returns {:ok, response} on success, {:error, reason} on failure.
  """
  def list(params \\ %{}) do
    query_params = URI.encode_query(Map.take(params, ["agent_type", "page_size", "cursor"]))
    endpoint = "#{@api_endpoint}/agents#{if query_params != "", do: "?#{query_params}", else: ""}"
    Common.get(endpoint)
  end

  @doc """
  Gets a specific agent by name.
  Returns {:ok, response} on success, {:error, reason} on failure.
  """
  def get(agent_name) do
    Common.get("#{@api_endpoint}/agents/#{agent_name}")
  end

  @doc """
  Lists all agent types.
  Returns {:ok, response} on success, {:error, reason} on failure.
  """
  def list_types do
    Common.get("#{@api_endpoint}/self_hosted_agent_types")
  end

  @doc """
  Creates a new agent type.
  Parameters:
    - metadata.name (required): name of the agent type
    - spec.agent_name_settings: configuration for agent name assignment
  Returns {:ok, response} on success, {:error, reason} on failure.
  """
  def create_type(params) do
    Common.post("#{@api_endpoint}/self_hosted_agent_types", params)
  end

  @doc """
  Updates an existing agent type.
  Returns {:ok, response} on success, {:error, reason} on failure.
  """
  def update_type(agent_type_name, params) do
    Common.patch("#{@api_endpoint}/self_hosted_agent_types/#{agent_type_name}", params)
  end

  @doc """
  Gets a specific agent type by name.
  Returns {:ok, response} on success, {:error, reason} on failure.
  """
  def get_type(agent_type_name) do
    Common.get("#{@api_endpoint}/self_hosted_agent_types/#{agent_type_name}")
  end

  @doc """
  Deletes an agent type.
  Returns {:ok, response} on success, {:error, reason} on failure.
  """
  def delete_type(agent_type_name) do
    Common.delete("#{@api_endpoint}/self_hosted_agent_types/#{agent_type_name}")
  end

  @doc """
  Disables agents for an agent type.
  Parameters:
    - only_idle (optional): boolean flag to control whether all agents are disabled or only idle ones
  Returns {:ok, response} on success, {:error, reason} on failure.
  """
  def disable_agents(agent_type_name, only_idle \\ true) do
    Common.post(
      "#{@api_endpoint}/self_hosted_agent_types/#{agent_type_name}/disable_all",
      %{only_idle: only_idle}
    )
  end
end
