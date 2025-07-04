defmodule FrontWeb.SchedulersView do
  use FrontWeb, :view

  def standardize_expression(expression) do
    case Front.Models.Scheduler.map_expression(expression) do
      {:ok, expression} -> expression
      {:error, message} -> message
    end
  end

  def time_ago(timestamp) do
    Phoenix.HTML.Tag.content_tag("time-ago", format_date(timestamp),
      datetime: format_date(timestamp)
    )
  end

  def target_link(project, scheduler) do
    branch = %{type: "branch", name: scheduler.branch, display_name: scheduler.branch}
    branch_url = human_accessible_repository_url(project, branch)

    Phoenix.HTML.Link.link("#{scheduler.branch} > #{scheduler.pipeline_file}",
      to: branch_url <> "/" <> scheduler.pipeline_file,
      class: "ml1 db link dark-gray underline-hover"
    )
  end

  def error_css_class(validations, field) do
    if validations && validations.errors && validations.errors[field],
      do: "form-control-error",
      else: ""
  end

  def task_icon(_scheduler = %{recurring: true}), do: "calendar_month"
  def task_icon(_scheduler = %{recurring: false}), do: "task_alt"

  def git_ref_icon("branch"), do: "fork_right"
  def git_ref_icon("tag"), do: "sell"
  def git_ref_icon("pr"), do: "call_merge"
  def git_ref_icon(_), do: "fork_right"

  def workflow_condition(nil),
    do: :MISCARRIED

  def workflow_condition(workflow) do
    root_pipeline = Enum.find(workflow.pipelines, &(&1.id == workflow.root_pipeline_id))
    workflow_condition(workflow, root_pipeline)
  end

  defp workflow_condition(%{hook: nil}, %{state: :DONE}), do: :MISCARRIED
  defp workflow_condition(%{hook: nil}, _root_pipeline), do: :CONCEIVING
  defp workflow_condition(_workflow, _root_pipeline), do: :DELIVERED

  def from_form(form, key) do
    if Map.has_key?(form.params, to_string(key)),
      do: Map.get(form.params, to_string(key)),
      else: Map.get(form.data, key)
  end

  def injectable(items) do
    items
    |> Enum.map(&Map.drop(&1, ~w(__struct__ __meta__)a))
    |> Poison.encode!(escape: :html_safe)
  end

  def neighbor_pages(page) do
    Enum.filter((page.number - 2)..(page.number + 2), &(&1 > 0 && &1 <= page.total_pages))
  end

  def page_link(path, page, curr_page) do
    class = if(page == curr_page, do: " b", else: "")
    class = "btn btn-secondary underline-hover mh1" <> class
    Phoenix.HTML.Link.link(page, to: path <> "?page=" <> Integer.to_string(page), class: class)
  end

  def form_sections do
    [
      [
        index: 1,
        name: "basics",
        title: "Name and description",
        template: "forms/_basics.html"
      ],
      [
        index: 2,
        name: "target",
        title: "What to run?",
        template: "forms/_target.html"
      ],
      [
        index: 3,
        name: "parameters",
        title: "Pipeline parameters (optional)",
        template: "forms/_parameters.html"
      ],
      [
        index: 4,
        name: "recurrence",
        title: "Scheduled runs (optional)",
        template: "forms/_recurrence.html"
      ]
    ]
  end
end
