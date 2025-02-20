defmodule Ppl.Actions.ListQueuesImpl do
  @moduledoc """
  Module which implements List queues action
  """

  alias Ppl.Queues.Model.QueuesQueries
  alias InternalApi.Plumber.QueueType
  alias Util.Proto

  import Ppl.Actions.ListImpl, only: [non_empty_value_or_default: 3]

  def list_queues(request) do
    with tf_map            <- %{QueueType => {__MODULE__, :list_to_string}},
         {:ok, params}     <- Proto.to_map(request, transformations: tf_map),
         {:ok, project_id} <- non_empty_value_or_default(params, :project_id, :skip),
         {:ok, org_id}     <- non_empty_value_or_default(params, :organization_id, :skip),
         queue_type        <- set_type(params.queue_types),
         true              <- required_fields_present?(queue_type, project_id, org_id),
         {:ok, page}       <- non_empty_value_or_default(params, :page, 1),
         {:ok, page_size}  <- non_empty_value_or_default(params, :page_size, 30),
         query_params      <- %{project_id: project_id, type: queue_type, org_id: org_id},
         {:ok, result}     <- QueuesQueries.list_queues(query_params, page, page_size)
    do
      {:ok, result}
    else
      e = {:error, _msg} -> e
      error -> {:error, error}
    end
  end

  def list_to_string(_name, value) do
    value |> QueueType.key() |> Atom.to_string() |> String.downcase()
  end

  defp set_type(list) when list == [], do: :skip
  defp set_type(list) when length(list) == 1, do: Enum.at(list, 0)
  defp set_type(list) when length(list) > 1, do: "all"

  defp required_fields_present?(:skip, _project_id, _org_id),
    do: {:error, "The 'queue_types' list in request must have at least one elemet."}
  defp required_fields_present?(_type, :skip, :skip),
    do: {:error, "Either 'project_id' or 'organization_id' parameters are required."}
  defp required_fields_present?(_type, _project_id, _org_id), do: true
end
