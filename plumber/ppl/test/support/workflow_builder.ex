defmodule Test.Support.WorkflowBuilder do
  @moduledoc """
  Allows easy building of desired workflow topology.
  Main function is `build` which creates workflow in one go, but other public
  functions with specific schedule actions can be used for gradual workflow building.
  """

  @doc """
  Builds workflow with given topology. Topology should be in form of a list where
  each element stands for one pipeline in workflow and is specified in form:
  {action, index_of_ancesestor, request_params} where:
   - action => way for creating pipeline, e.g. :schedule, :partial_rebuild, :schedule_extension
   - index_of_ancesestor => index in topology list of pipeline whose extension/rebuild
                            should this pipeline be, [not used for plain schedule action]
   - request_params => [optional] (some of) params for schedule(_extension)/rebuild request

  Topology list should have only one element with ':schedule' action, and it should be
  first element of the list.
  """
  def build(topology) do
    topology
    |> Enum.map(fn elem -> expand_to_3_tuple(elem) end)
    |> Enum.reduce([], fn {action, index, params}, acc ->
      resp = apply(__MODULE__, action, get_args(action, acc, index, params))
      acc ++ [resp]
    end)
  end

  defp expand_to_3_tuple({a, b}), do: {a, b, %{}}
  defp expand_to_3_tuple({a, b, c}), do: {a, b, c}

  defp get_args(:schedule, _list, _index, params),  do: [params]
  defp get_args(_action, list, index, params)  do
    case Enum.at(list, index, %{}) do
      {:ok, wf_if, ppl_id} -> [wf_if, params |> Map.merge(%{ppl_id: ppl_id})]
      e -> {:error, e}
    end
  end

  def describe(wf_id) do
     GenServer.call(:workflow_builder_impl, {:describe, wf_id}, 10_000)
  end

  def schedule(params) do
     GenServer.call(:workflow_builder_impl, {:schedule, params}, 10_000)
  end

  def schedule_extension(wf_id, params) do
     GenServer.call(:workflow_builder_impl, {:schedule_extension, wf_id, params}, 10_000)
  end

  def partial_rebuild(wf_id, %{ppl_id: ppl_id}) do
     GenServer.call(:workflow_builder_impl, {:partial_rebuild, wf_id, ppl_id}, 31_000)
  end
end