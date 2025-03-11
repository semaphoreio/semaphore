defmodule FrontWeb.DeploymentsView do
  use FrontWeb, :view
  alias Front.Models.DeploymentDetails
  alias Front.Models.DeploymentDetails.Deployment
  alias Front.Models.RepoProxy

  def time_ago(timestamp) do
    Phoenix.HTML.Tag.content_tag("time-ago", format_date(timestamp),
      datetime: format_date(timestamp)
    )
  end

  def has_promotion_parameters?(details = %DeploymentDetails{}) do
    parameter_names = ~w(parameter_name_1 parameter_name_2 parameter_name_3)a
    details |> Map.take(parameter_names) |> Map.values() |> Enum.any?(&(String.length(&1) > 0))
  end

  def deployment_state(deployment = %Deployment{state: :STARTED}),
    do: pipeline_state(deployment.pipeline.state, deployment.pipeline.result)

  def deployment_state(%Deployment{state: :FAILED}), do: :FAILED
  def deployment_state(%Deployment{state: :PENDING}), do: :RUNNING

  defp pipeline_state(:DONE, :PASSED), do: :PASSED
  defp pipeline_state(:DONE, :STOPPED), do: :CANCELLED
  defp pipeline_state(:DONE, :CANCELLED), do: :CANCELLED
  defp pipeline_state(:DONE, :FAILED), do: :FAILED
  defp pipeline_state(_state, _result), do: :RUNNING

  def details_color(:RUNNING), do: "blue"
  def details_color(:PASSED), do: "green"
  def details_color(:FAILED), do: "red"
  def details_color(:CANCELLED), do: "gray"

  def details_title(:RUNNING), do: "Deployment in progress"
  def details_title(:PASSED), do: "Last deployment"
  def details_title(:FAILED), do: "Last deployment"
  def details_title(:CANCELLED), do: "Last deployment"

  def details_circle(:RUNNING), do: "circle"
  def details_circle(:PASSED), do: "check_circle"
  def details_circle(:FAILED), do: "cancel"
  def details_circle(:CANCELLED), do: "do_not_disturb_on"

  def git_ref_icon(%RepoProxy{type: type}),
    do: git_ref_icon(type)

  def git_ref_icon("branch"), do: "fork_right"
  def git_ref_icon("tag"), do: "sell"
  def git_ref_icon("pr"), do: "call_merge"
  def git_ref_icon(_), do: "fork_right"

  def object_mode_icon(:ALL), do: "check"
  def object_mode_icon(:NONE), do: "close"
  def object_mode_icon(:WHITELISTED), do: "rule"

  def injectable(items) do
    items
    |> Enum.map(&Map.drop(&1, ~w(__struct__ __meta__)a))
    |> Poison.encode!(escape: :html_safe)
  end

  def from_form(form, key) do
    if Map.has_key?(form.params, to_string(key)),
      do: Map.get(form.params, to_string(key)),
      else: Map.get(form.data, key)
  end

  def options(resources, resource_name) do
    to_option = &[key: &1.name, value: &1.id]

    resources
    |> Map.get(resource_name, [])
    |> Enum.into([], to_option)
  end

  def form_sections do
    [
      [
        index: 1,
        name: "basics",
        title: "Name, description and URL",
        template: "forms/_basics.html"
      ],
      [
        index: 2,
        name: "credentials",
        title: "Credentials",
        template: "forms/_credentials.html"
      ],
      [
        index: 3,
        name: "subjects",
        title: "Who can deploy?",
        template: "forms/_subject_rules.html"
      ],
      [
        index: 4,
        name: "objects",
        title: "Limits for branches and tags",
        template: "forms/_object_rules.html"
      ]
    ]
  end
end
