defmodule Ppl.WorkflowActions do
  @moduledoc """
  Actions performed on workflow level
  """

  alias Ppl.PplRequests.Model.PplRequestsQueries

  @doc """
  Finds ppl_artefact_id of first pipeline in path based on given params.
  - If first_ppl_id is provided =>
      returns ppl_artefact_id of pipeline with given id
  - Else if last_ppl_id is provided =>
      returns ppl_artefact_id of rebuild partition of initaial pipeline from
      which subtree containing pipeline with given ppl_id originated
  - Else if wf_id is provided =>
      returns ppl_artefact_id of rebuild partition of initaial pipeline
      in given workflow
  - Else => error - Invalid params
  """
  def get_frist_ppl_artefact_id(path_request) do
    path_request
    |> first_by_first_ppl_id()
    |> first_by_last_ppl_id(path_request)
    |> first_by_wf_id(path_request)
  end

  defp first_by_first_ppl_id(%{first_ppl_id: ppl_id})
    when is_binary(ppl_id) and ppl_id != "" do
      case PplRequestsQueries.get_by_id(ppl_id) do
        {:ok, ppl_req} -> {:ok, ppl_req.ppl_artefact_id}
        error -> error
      end
  end
  defp first_by_first_ppl_id(_path_request), do: :not_found

  defp first_by_last_ppl_id(:not_found, %{last_ppl_id: ppl_id})
    when is_binary(ppl_id) and ppl_id != "" do
      with {:ok, last_ppl}    <- PplRequestsQueries.get_by_id(ppl_id),
           {:ok, initial_ppl} <- PplRequestsQueries.get_initial_wf_ppl(last_ppl.wf_id),
      do: {:ok, initial_ppl.ppl_artefact_id}
  end
  defp first_by_last_ppl_id(previous_result, _path_request), do: previous_result

  defp first_by_wf_id(:not_found, %{wf_id: wf_id})
    when is_binary(wf_id) and wf_id != "" do
      case PplRequestsQueries.get_initial_wf_ppl(wf_id) do
        {:ok, ppl_req} -> {:ok, ppl_req.ppl_artefact_id}
        error -> error
      end
  end
  defp first_by_wf_id(:not_found, _path_request),
    do: {:error, "Invalid request - none of the parameters is a valid pipeline id."}
  defp first_by_wf_id(previous_result, _path_request), do: previous_result


  @doc """
  Finds PplRequest of last pipeline in path based on given params.
  - If last_ppl_id is provided =>
      returns PplRequest of pipeline with given id
  - Else if first_ppl_id is provided =>
      returns PplRequest of latest pipeline in subtree which originated from
      pipeline with given ppl_id
  - Else if wf_id is provided =>
      returns PplRequest of latest pipeline in workflow with given wf_id
  - Else => error - Invalid params
  """
  def get_last_ppl_req(path_request) do
    path_request
    |> last_by_last_ppl_id()
    |> last_by_first_ppl_id(path_request)
    |> last_by_wf_id(path_request)
  end

  defp last_by_last_ppl_id(%{last_ppl_id: ppl_id})
    when is_binary(ppl_id) and ppl_id != "" do
      PplRequestsQueries.get_by_id(ppl_id)
  end
  defp last_by_last_ppl_id(_path_request), do: :not_found

  defp last_by_first_ppl_id(:not_found, %{first_ppl_id: ppl_id})
    when is_binary(ppl_id) and ppl_id != "" do
      PplRequestsQueries.latest_ppl_from_subtree(ppl_id)
  end
  defp last_by_first_ppl_id(previous_result, _path_request), do: previous_result

  defp last_by_wf_id(:not_found, %{wf_id: wf_id})
    when is_binary(wf_id) and wf_id != "" do
      PplRequestsQueries.latest_ppl_from_workflow(wf_id)
  end
  defp last_by_wf_id(:not_found, _path_request),
    do: {:error, "Invalid request - none of the parameters is a valid pipeline id."}
  defp last_by_wf_id(previous_result, _path_request), do: previous_result

  @doc """
  Creates full path between given first and last pipeline.
  """
  def find_path(first_ppl_a_id, last_ppl_req) do
    {:ok, all_wf_ppls} = PplRequestsQueries.get_all_by_wf_id(last_ppl_req.wf_id)

    last_ppl_req.prev_ppl_artefact_ids ++ [last_ppl_req.ppl_artefact_id]
    |> Enum.reverse()
    |> Enum.reduce_while({last_ppl_req.id, []}, fn a_id, {ppl_id, acc} ->

      rebuild_partition = filter_rebuild_partition(all_wf_ppls, a_id)

      relevant_ppl = rebuild_partition |> Enum.find(fn ppl_req -> ppl_req.id == ppl_id end)

      path_elem = form_path_elem_map(rebuild_partition, relevant_ppl)

      case relevant_ppl.ppl_artefact_id == first_ppl_a_id do
        true -> {:halt, {:ok, [path_elem] ++ acc}}
        _ -> {:cont, {relevant_ppl.request_args["extension_of"], [path_elem] ++ acc}}
      end
    end)
  end

  defp filter_rebuild_partition(all_wf_ppls, a_id) do
    all_wf_ppls
    |> Enum.filter(fn ppl_req -> ppl_req.ppl_artefact_id == a_id end)
    |> Enum.sort(fn ppl_1, ppl_2 ->
      NaiveDateTime.compare(ppl_1.inserted_at, ppl_2.inserted_at) == :lt
    end)
  end

  defp form_path_elem_map(rebuild_partition, relevant_ppl) do
    %{
      ppl_id: relevant_ppl.id,
      switch_id: relevant_ppl.switch_id || "",
      rebuild_partition: rebuild_partition |> Enum.map(fn ppl_req -> ppl_req.id end)
    }
  end

  @doc """
  Get details of workflow with given wf_id
  """
  def get_wf_details(wf_id) do
    case PplRequestsQueries.get_initial_wf_ppl(wf_id) do
      {:ok, initial_ppl_req} -> {:ok, %{wf_id: wf_id, wf_created_at: initial_ppl_req.inserted_at}}
      e = {:error, _msq} -> e
      e -> {:error, e}
    end
  end
end
