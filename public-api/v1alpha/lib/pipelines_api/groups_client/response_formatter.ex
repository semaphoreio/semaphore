defmodule PipelinesAPI.GroupsClient.ResponseFormatter do
  @moduledoc false
  def process_list_response({:ok, response}) do
    groups = Enum.map(response.groups, &serialize/1)
    {:ok, %{groups: groups}}
  end

  def process_list_response(error), do: error

  def process_create_response({:ok, response}) do
    {:ok, serialize(response.group)}
  end

  def process_create_response(error), do: error

  def process_modify_response({:ok, response}) do
    {:ok, serialize(response.group)}
  end

  def process_modify_response(error), do: error

  def process_destroy_response({:ok, _response}), do: {:ok, %{status: "deleted"}}
  def process_destroy_response(error), do: error

  defp serialize(group) do
    %{
      id: group.id,
      name: group.name,
      description: group.description,
      member_ids: group.member_ids
    }
  end
end
