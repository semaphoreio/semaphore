defmodule Ppl.Actions.Limits.ScheduleLimits do
  @moduledoc """
    check_limit - checks if the limit of allowed queuing pipelines has been exceeded
  """
  alias Ppl.Ppls.Model.PplsQueries
  alias Ppl.Queues.Model.QueuesQueries
  alias Ppl.RequestReviser
  alias Block.CodeRepo.Expand


  def check_limit(request_args, n) do
    req_args = RequestReviser.revise(request_args)
    %{"file_name" => file_name, "working_dir" => working_dir} = req_args
    yml_file_path = Expand.full_name(working_dir, file_name)
    label = req_args["label"] || to_label(req_args["branch_name"])

    ppl_to_be =
      req_args
      |> Map.new(fn {k, v} -> to_atom(k, v) end)
      |> Map.merge(%{id: "0", yml_file_path: yml_file_path, label: label})

    %{name: "#{label}-#{yml_file_path}", project_id: req_args["project_id"],
      scope: "project"}
     |> QueuesQueries.get_by_name_and_id()
     |> case do
       {:ok, %{queue_id: queue_id}} ->
         ppl_to_be |> Map.put(:queue_id, queue_id) |> check_limit_(n)

        _not_found ->
          {:ok}
      end
  end

  defp check_limit_(ppl_to_be, n) do
    # ppl_to-be is a pipeline that is not yet created but request for its scheduling
    # is received because number of ppls preceeding it needs to be checked.
    case PplsQueries.all_ppls_from_same_queue_in_states(
            ppl_to_be, ["pending", "queuing", "running"]) do
      {:ok, events_list} ->
        if length(events_list) >= n  do
          {:limit, "Limit of queuing pipelines reached"}
        else
          {:ok}
        end
      error -> error
    end
  end

  defp to_label("refs/tags/" <> label), do: label
  defp to_label("pull-request-" <> label), do: label
  defp to_label(label), do: label

  defp to_atom(k, v) when is_atom(k), do: {k, v}
  defp to_atom(k, v), do: {String.to_atom(k), v}

end
