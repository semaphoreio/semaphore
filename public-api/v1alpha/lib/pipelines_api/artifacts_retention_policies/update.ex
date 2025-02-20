defmodule PipelinesAPI.ArtifactsRetentionPolicy.Update do
  @moduledoc """
  Plug which updates (by default, policy is "never delete") artifacts
  retention policies for a given project based on given data.
  """

  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.ArtifactHubClient
  alias PipelinesAPI.Util.VerifyData, as: VD

  import PipelinesAPI.ArtifactsRetentionPolicy.Common,
    only: [get_artifact_store_id: 2]

  import PipelinesAPI.ArtifactsRetentionPolicy.Authorize,
    only: [authorize_manage_retention_policy: 2]

  @enabled_fields ~w(project_id project_level_retention_policies
    workflow_level_retention_policies job_level_retention_policies)

  plug(:verify_params)
  plug(:authorize_manage_retention_policy)
  plug(:get_artifact_store_id)
  plug(:update_retention_policy)

  def update_retention_policy(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["retention_apply"], fn ->
      conn.params
      |> ArtifactHubClient.update_retention_policy()
      |> RespCommon.respond(conn)
    end)
  end

  def verify_params(conn, _otps) do
    VD.verify(
      VD.is_present_string?(conn.params["project_id"]),
      "project_id must be present"
    )
    |> VD.verify(
      VD.is_valid_uuid?(conn.params["project_id"]),
      "project id must be a valid UUID"
    )
    |> verify_at_lease_one_rule_present(conn.params)
    |> verify_rules(conn.params["project_level_retention_policies"])
    |> verify_rules(conn.params["workflow_level_retention_policies"])
    |> verify_rules(conn.params["job_level_retention_policies"])
    |> VD.finalize_verification(conn, @enabled_fields)
  end

  defp verify_at_lease_one_rule_present(result, params) do
    result
    |> VD.verify(
      VD.non_empty_list?(params["project_level_retention_policies"]) or
        VD.non_empty_list?(params["workflow_level_retention_policies"]) or
        VD.non_empty_list?(params["job_level_retention_policies"]),
      "at least one retention policy configuration must be defined"
    )
  end

  defp verify_rules(result, nil), do: result

  defp verify_rules(error = {:error, _}, _list), do: error

  defp verify_rules(result, list) do
    Enum.map(list, fn rule ->
      result
      |> VD.verify(
        VD.is_present_string?(rule["selector"]),
        "the 'selector' filed must be a non-empty string"
      )
      |> VD.verify(
        VD.is_present_string?(rule["age"]),
        "the 'age' fields must be a string, valid examples: 5 days, 1 week, 2 weeks, 3 months, 4 years"
      )
      |> VD.verify(
        is_binary(rule["age"]) and
          String.match?(
            rule["age"],
            ~r/^(1[0-2]|[1-9])\s(?:day|days|week|weeks|month|months|year|years)$/
          ),
        "invalid 'age' value: '#{rule["age"]}' - valid examples: 5 days, 1 week, 2 weeks, 3 months, 4 years"
      )
      |> VD.verify(
        is_binary(rule["age"]) and
          more_than_a_day(rule["age"]),
        "the 'age' lowest value is 1 day"
      )
    end)
    |> Enum.find(:ok, fn resp -> is_tuple(resp) and elem(resp, 0) == :error end)
  end

  defp more_than_a_day(value) do
    case String.split(value, " ") do
      [num, _unit] ->
        case String.to_integer(num) do
          n when n >= 1 -> true
          _ -> false
        end

      _ ->
        false
    end
  end
end
