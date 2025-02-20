defmodule Gofer.PlumberClient.RequestFormatter do
  @moduledoc """
  Module serves transform data in proto message format suitable for communication
  via gRPC with Plumber service.
  """

  alias InternalApi.Plumber.{ScheduleExtensionRequest, DescribeRequest}
  alias Util.{ToTuple, Proto}

  # ScheduleExtension

  def form_schedule_extension_request(params) do
    params
    |> atom_keys()
    |> Proto.deep_new(ScheduleExtensionRequest)
  end

  defp atom_keys(map) when is_map(map) do
    map |> Enum.map(fn {k, v} -> {to_atom(k), atom_keys(v)} end) |> Enum.into(%{})
  end

  defp atom_keys(list) when is_list(list) do
    list |> Enum.map(fn item -> atom_keys(item) end)
  end

  defp atom_keys(value), do: value

  defp to_atom(atom) when is_atom(atom), do: atom
  defp to_atom(string) when is_binary(string), do: String.to_atom(string)

  # Describe

  def form_describe_request(pipeline_id) when is_binary(pipeline_id) do
    %{ppl_id: pipeline_id, detailed: false}
    |> DescribeRequest.new()
    |> ToTuple.ok()
  end

  def form_describe_request(_error),
    do: "Parameter pipeline_id must be a string." |> ToTuple.error()
end
