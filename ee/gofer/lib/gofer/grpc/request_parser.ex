defmodule Gofer.Grpc.RequestParser do
  @moduledoc """
  Module serves to parse received protobuf request messages and transforms them
  into format suitable for actions in Actions modules.
  """
  alias InternalApi.Gofer.{
    CreateRequest,
    PipelineDoneRequest,
    DescribeRequest,
    ListTriggerEventsRequest,
    TriggerRequest,
    DescribeManyRequest,
    GitRefType
  }

  alias Util.Proto

  @max_resp_elements 100
  @defult_resp_elements 10

  def parse(request = %CreateRequest{}) do
    with {:ok, map} <-
           Proto.to_map(request,
             string_keys: true,
             transformations: %{GitRefType => {__MODULE__, :atom_to_lower_string}}
           ),
         {targets, map} <- {map["targets"], map |> Map.delete("targets")},
         switch <-
           map |> Map.put("ppl_id", map["pipeline_id"]) |> Map.delete("pipeline_id") do
      {:ok, switch, targets}
    else
      e -> {:error, {:missing_required_keys, e}}
    end
  end

  def parse(request = %PipelineDoneRequest{}) do
    with request_map <- string_keys(request),
         %{"switch_id" => switch_id, "result" => result, "result_reason" => result_reason} <-
           request_map do
      {:ok, switch_id, result, result_reason}
    else
      e -> {:error, e}
    end
  end

  def parse(request = %TriggerRequest{}) do
    with request_map <- Map.from_struct(request),
         {:triggered_by_set, true} <- {:triggered_by_set, request_map.triggered_by != ""} do
      {:ok, request_map}
    else
      {:triggered_by_set, false} -> {:error, "Field triggered_by can not be empty."}
      e -> {:error, e}
    end
  end

  def parse(request = %ListTriggerEventsRequest{}) do
    with %{switch_id: switch_id, page: page, page_size: page_size} <- request,
         {:ok, target_name} <- non_empty_value_or_default(request, :target_name, :skip),
         {:page_valid, true} <- {:page_valid, is_integer(page) and page >= 1},
         {:page_size_valid, true} <-
           {:page_size_valid,
            is_integer(page_size) and
              page_size >= 1 and
              page_size < @max_resp_elements} do
      {:ok, switch_id, target_name, page, page_size}
    else
      {:page_valid, false} ->
        {:error, "Page parameter must be integer greater or equal to 1."}

      {:page_size_valid, false} ->
        {:error,
         "Page_size parameter must be integer greater or equal to 1 and lesser than #{@max_resp_elements}."}

      e ->
        {:error, e}
    end
  end

  def parse(request = %DescribeRequest{}) do
    with %{switch_id: switch_id, events_per_target: trigger_no, requester_id: requester_id} <-
           request,
         {:ok, trigger_no} <- events_per_target_valid?(trigger_no) do
      {:ok, switch_id, trigger_no, requester_id}
    else
      e -> {:error, e}
    end
  end

  def parse(request = %DescribeManyRequest{}) do
    with %{switch_ids: switch_ids, events_per_target: trigger_no, requester_id: requester_id} <-
           request,
         {:ok, trigger_no} <- events_per_target_valid?(trigger_no) do
      {:ok, switch_ids, trigger_no, requester_id}
    else
      e -> {:error, e}
    end
  end

  defp events_per_target_valid?(0), do: {:ok, @defult_resp_elements}

  defp events_per_target_valid?(trigger_no)
       when is_integer(trigger_no) and trigger_no > 0 and trigger_no <= @max_resp_elements,
       do: {:ok, trigger_no}

  defp events_per_target_valid?(trigger_no) do
    """
    Invalid value of events_per_target parameter: #{inspect(trigger_no)}.
    It has to be integer betwen 1 and #{inspect(@max_resp_elements)}.
    """
  end

  defp non_empty_value_or_default(map, key, default) do
    case Map.get(map, key) do
      val when is_binary(val) and val != "" -> {:ok, val}
      _ -> {:ok, default}
    end
  end

  defp string_keys(map), do: map |> Poison.encode!() |> Poison.decode!()

  def atom_to_lower_string(_name, value) do
    value |> Atom.to_string() |> String.downcase()
  end
end
