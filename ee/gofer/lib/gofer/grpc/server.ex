defmodule Gofer.Grpc.Server do
  @moduledoc """
  Module implements gRPC server which exposes endpoints defined in InternalAPI
  proto definition.
  """
  use GRPC.Server, service: InternalApi.Gofer.Switch.Service

  alias InternalApi.Gofer.VersionResponse
  alias Gofer.Grpc.RequestParser
  alias Gofer.Grpc.ResponseFormatter
  alias Gofer.Actions
  alias Util.Metrics

  def create(create_request, _stream) do
    Metrics.benchmark("Gofer.create", __MODULE__, fn ->
      with {:ok, switch_def, targets_defs} <- RequestParser.parse(create_request),
           {:ok, id} <- Actions.create_switch(switch_def, targets_defs) do
        {:ok, id} |> ResponseFormatter.form_response(:create)
      else
        e = {:error, _msg} -> ResponseFormatter.form_response(e, :create)
        e -> {:error, e} |> ResponseFormatter.form_response(:create)
      end
    end)
  end

  def pipeline_done(ppl_done_req, _stream) do
    Metrics.benchmark("Gofer.pipeline_done", __MODULE__, fn ->
      with {:ok, switch_id, ppl_result, ppl_result_reason} <- RequestParser.parse(ppl_done_req),
           {:ok, action_result} <-
             Actions.proces_ppl_done_request(switch_id, ppl_result, ppl_result_reason) do
        {:ok, action_result} |> ResponseFormatter.form_response(:pipeline_done)
      else
        e -> {:error, e} |> ResponseFormatter.form_response(:pipeline_done)
      end
    end)
  end

  def trigger(trigger_request, _stream) do
    Metrics.benchmark("Gofer.trigger", __MODULE__, fn ->
      with {:ok, request_params} <- RequestParser.parse(trigger_request),
           {:ok, action_result} <- Actions.trigger(request_params) do
        {:ok, action_result} |> ResponseFormatter.form_response(:trigger)
      else
        e -> {:error, e} |> ResponseFormatter.form_response(:trigger)
      end
    end)
  end

  def describe(describe_request, _stream) do
    Metrics.benchmark("Gofer.describe", __MODULE__, fn ->
      with {:ok, switch_id, triggers_no, requester_id} <- RequestParser.parse(describe_request),
           {:ok, action_result} <- Actions.describe_switch(switch_id, triggers_no, requester_id) do
        {:ok, action_result} |> ResponseFormatter.form_response(:describe)
      else
        e -> {:error, e} |> ResponseFormatter.form_response(:describe)
      end
    end)
  end

  def describe_many(describe_many_request, _stream) do
    Metrics.benchmark("Gofer.describe_many", __MODULE__, fn ->
      with {:ok, switch_ids, triggers_no, requester_id} <-
             RequestParser.parse(describe_many_request),
           {:ok, action_result} <- Actions.describe_many(switch_ids, triggers_no, requester_id) do
        {:ok, action_result} |> ResponseFormatter.form_response(:describe_many)
      else
        e -> {:error, e} |> ResponseFormatter.form_response(:describe_many)
      end
    end)
  end

  def list_trigger_events(list_request, _stream) do
    Metrics.benchmark("Gofer.list_trigger_events", __MODULE__, fn ->
      with {:ok, switch_id, target_name, page, page_size} <- RequestParser.parse(list_request),
           {:ok, action_result} <- Actions.list_triggers(switch_id, target_name, page, page_size) do
        {:ok, action_result} |> ResponseFormatter.form_response(:list_triggers)
      else
        e -> {:error, e} |> ResponseFormatter.form_response(:list_triggers)
      end
    end)
  end

  def version(_, _stream) do
    version =
      :application.loaded_applications()
      |> Enum.find(fn {k, _, _} -> k == :gofer end)
      |> elem(2)
      |> List.to_string()

    VersionResponse.new(version: version)
  end
end
