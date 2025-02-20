defmodule PipelinesAPI.ArtifactHubClient do
  @moduledoc """
  Module is used for communication with ArtifactsHub service over gRPC.
  """

  alias PipelinesAPI.Util.{Log, Metrics, ToTuple}

  alias InternalApi.Artifacthub.{
    ArtifactService,
    UpdateRetentionPolicyRequest,
    RetentionPolicy,
    DescribeRequest
  }

  alias Util.Proto

  require Logger

  @one_day 24 * 3600
  @one_week 7 * 24 * 3600
  @one_month 30 * 24 * 3600
  @one_year 365 * 24 * 3600

  defp url(), do: System.get_env("ARTIFACTS_HUB_URL")
  defp opts(), do: [{:timeout, Application.get_env(:pipelines_api, :grpc_timeout)}]

  # Describe

  def describe_retention_policy(params) do
    Metrics.benchmark("PipelinesAPI.artifacts_hub_client", ["describe"], fn ->
      params
      |> form_describe_request()
      |> describe()
      |> serialize_policy_response()
    end)
  end

  defp form_describe_request(params) do
    %{
      artifact_id: params |> Map.get("artifact_store_id", ""),
      include_retention_policy: true
    }
    |> DescribeRequest.new()
    |> ToTuple.ok()
  catch
    error -> error
  end

  defp describe({:ok, request}) do
    result = Wormhole.capture(__MODULE__, :describe_, [request], stacktrace: true, skip_log: true)

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "describe", "ArtifactsHub")
    end
  end

  defp describe(error), do: error

  def describe_(describe_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.artifacts_hub_client.grpc_client", ["describe"], fn ->
      channel
      |> ArtifactService.Stub.describe(describe_request, opts())
      |> process_response("describe")
    end)
  end

  # Update

  def update_retention_policy(params) do
    Metrics.benchmark("PipelinesAPI.artifacts_hub_client", ["update"], fn ->
      params
      |> form_update_request()
      |> update()
      |> serialize_policy_response()
    end)
  end

  defp form_update_request(params) do
    %{
      artifact_id: params |> Map.get("artifact_store_id", ""),
      retention_policy:
        %{
          project_level_retention_policies:
            parse_policies(params["project_level_retention_policies"]),
          workflow_level_retention_policies:
            parse_policies(params["workflow_level_retention_policies"]),
          job_level_retention_policies: parse_policies(params["job_level_retention_policies"])
        }
        |> RetentionPolicy.new()
    }
    |> UpdateRetentionPolicyRequest.new()
    |> ToTuple.ok()
  catch
    error -> error
  end

  defp parse_policies(nil), do: []

  defp parse_policies(policies) do
    Enum.map(policies, fn policy ->
      %{
        selector: policy["selector"] || "",
        age: age_string_to_seconds(policy["age"])
      }
      |> RetentionPolicy.RetentionPolicyRule.new()
    end)
  end

  defp age_string_to_seconds(nil), do: 0

  defp age_string_to_seconds(age_string) do
    [num_string, unit] = String.split(age_string)
    num = String.to_integer(num_string)

    cond do
      unit in ["day", "days"] -> num * @one_day
      unit in ["week", "weeks"] -> num * @one_week
      unit in ["month", "months"] -> num * @one_month
      unit in ["year", "years"] -> num * @one_year
      true -> 0
    end
  end

  defp update({:ok, request}) do
    result = Wormhole.capture(__MODULE__, :update_, [request], stacktrace: true, skip_log: true)

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "update", "ArtifactsHub")
    end
  end

  defp update(error), do: error

  def update_(update_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.artifacts_hub_client.grpc_client", ["update"], fn ->
      channel
      |> ArtifactService.Stub.update_retention_policy(update_request, opts())
      |> process_response("update")
    end)
  end

  # Utility

  defp serialize_policy_response({:ok, proto_response}) do
    with {:ok, response} <- Proto.to_map(proto_response),
         result <-
           Map.drop(
             response.retention_policy,
             [:scheduled_for_cleaning_at, :last_cleaned_at]
           ) do
      result |> transform_age_in_retention_policies()
    end
  end

  defp serialize_policy_response(error), do: error

  defp transform_age_in_retention_policies(map) do
    %{
      project_level_retention_policies:
        age_fields_to_string(map.project_level_retention_policies),
      workflow_level_retention_policies:
        age_fields_to_string(map.workflow_level_retention_policies),
      job_level_retention_policies: age_fields_to_string(map.job_level_retention_policies)
    }
    |> ToTuple.ok()
  end

  defp age_fields_to_string(policies) do
    Enum.map(policies, fn policy ->
      age_field_to_string(policy)
    end)
  end

  defp age_field_to_string(policy) do
    cond do
      rem(policy.age, @one_year) == 0 ->
        num = div(policy.age, @one_year)
        unit = if num == 1, do: "year", else: "years"
        Map.put(policy, :age, "#{num} " <> unit)

      rem(policy.age, @one_month) == 0 ->
        num = div(policy.age, @one_month)
        unit = if num == 1, do: "month", else: "months"
        Map.put(policy, :age, "#{num} " <> unit)

      rem(policy.age, @one_week) == 0 ->
        num = div(policy.age, @one_week)
        unit = if num == 1, do: "week", else: "weeks"
        Map.put(policy, :age, "#{num} " <> unit)

      true ->
        num = div(policy.age, @one_day)
        unit = if num == 1, do: "day", else: "days"
        Map.put(policy, :age, "#{num} " <> unit)
    end
  end

  defp process_response({:ok, response}, _action), do: {:ok, response}

  defp process_response(
         {:error, _error = %GRPC.RPCError{message: message, status: status}},
         action
       ) do
    cond do
      # FailedPrecondition
      status == 9 ->
        ToTuple.user_error(message)

      # NotFound
      status == 5 ->
        ToTuple.not_found_error("artifats retention policy not found")

      true ->
        Log.internal_error(message, action, "ArtifactHub")
    end
  end

  defp process_response({:error, error}, action) do
    Logger.error("Error on #{action}: #{inspect(error)}")
    error |> Log.internal_error(action, "ArtifactHub")
  end

  defp process_response(error, action) do
    Logger.error("Error on #{action}: #{inspect(error)}")
    error |> Log.internal_error(action, "ArtifactHub")
  end
end
