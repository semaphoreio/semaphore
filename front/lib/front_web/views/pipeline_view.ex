# credo:disable-for-this-file Credo.Check.Readability.MaxLineLength
# credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode

defmodule FrontWeb.PipelineView do
  require Logger
  use FrontWeb, :view

  def tree_view(conn, workflow) do
    {:safe, __MODULE__.PipelineTree.render(conn, workflow)}
  end

  def interactive_tree_view(pipelines, other) do
    {:safe, __MODULE__.InteractivePipelineTree.render(pipelines, other)}
  end

  defmodule InteractivePipelineTree do
    @moduledoc """
    Displays an interactive tree view of pipelines in a workflow.
    Output is similar to PipelineTree view, with additional JS hooks.
    """

    alias FrontWeb.PipelineView.TreeLike

    def render(pipelines, other_params) do
      first = TreeLike.find_top_pipeline(pipelines)
      rest = Enum.filter(pipelines, fn p -> p.id != first end)

      draw_subtree(first, 0, rest, other_params)
    end

    defp draw_subtree(root_pipeline, depth, pipelines, other_params) do
      render_params =
        [pipeline: root_pipeline, tree_connector: TreeLike.tree_connector(depth)] ++ other_params

      root = render_pipeline(render_params)

      {direct_children, rest} =
        TreeLike.direct_children_of(
          root_pipeline.id,
          pipelines
        )

      children =
        direct_children
        |> Enum.map(fn p -> draw_subtree(p, depth + 1, rest, other_params) end)

      ([root] ++ children)
      |> Enum.join("\n")
    end

    defp render_pipeline(params) do
      {:safe, render} = FrontWeb.WorkflowView.render("status/_interactive_pipeline.html", params)

      render
    end
  end

  defmodule PipelineTree do
    @moduledoc """
    Displays a tree view of pipelines in a workflow. The input is the list of the
    pipelines execcuted in one workflow. The output is a tree view html.

    Example output:

    Passed Build & Test ⋮ 00:23
    Passed └ Deploy to Staging ⋮ 01:09
    Passed    └ Deploy to Production ⋮ 01:09
    Passed    └ Deploy to Production ⋮ 01:09
    """

    alias FrontWeb.PipelineView.TreeLike

    def render(conn, workflow) do
      pipelines = workflow.pipelines
      other_params = [conn: conn, workflow: workflow, selected_pipeline_id: nil]
      first = TreeLike.find_top_pipeline(pipelines)
      rest = Enum.filter(pipelines, fn p -> p.id != first end)

      draw_subtree(first, 0, rest, other_params)
    end

    defp draw_subtree(root_pipeline, depth, pipelines, other_params) do
      render_params =
        [pipeline: root_pipeline, tree_connector: TreeLike.tree_connector(depth)] ++ other_params

      root = render_pipeline(render_params)

      {direct_children, rest} =
        TreeLike.direct_children_of(
          root_pipeline.id,
          pipelines
        )

      children =
        direct_children
        |> Enum.map(fn p -> draw_subtree(p, depth + 1, rest, other_params) end)

      ([root] ++ children)
      |> Enum.join("\n")
    end

    defp render_pipeline(params) do
      FrontWeb.WorkflowView.render("status/_pipeline.html", params)
      |> then(fn {:safe, html} ->
        html
      end)
    end
  end

  defmodule TreeLike do
    def find_top_pipeline(pipelines) when length(pipelines) == 1 do
      Enum.at(pipelines, 0)
    end

    def find_top_pipeline(pipelines) do
      pipelines
      |> Enum.find(fn p ->
        p.promotion_of == "" and p.partial_rerun_of == ""
      end)
    end

    def direct_children_of(pipeline_id, pipelines) do
      children = Enum.filter(pipelines, fn p -> direct_child?(pipeline_id, p) end)
      rest = Enum.filter(pipelines, fn p -> !direct_child?(pipeline_id, p) end)

      {children, rest}
    end

    def tree_connector(depth) do
      case depth do
        0 ->
          ""

        1 ->
          "<span class='mid-gray mr1'>└</span>"

        _ ->
          pad_to_left = 24 * (depth - 1)
          "<span class='mid-gray mr1' style='padding-left: #{pad_to_left}px'>└</span>"
      end
    end

    defp direct_child?(parent_id, child) do
      child.promotion_of == parent_id || child.partial_rerun_of == parent_id
    end
  end

  def pipeline_favicon_status(pipeline),
    do: pipeline_favicon_status(pipeline.state, pipeline.result)

  defp pipeline_favicon_status(:RUNNING, _), do: "running"
  defp pipeline_favicon_status(:STOPPING, _), do: "stopping"
  defp pipeline_favicon_status(:DONE, :PASSED), do: "passed"
  defp pipeline_favicon_status(:DONE, :FAILED), do: "failed"
  defp pipeline_favicon_status(:DONE, :STOPPED), do: "stopped"
  defp pipeline_favicon_status(:DONE, :CANCELED), do: "canceled"
  defp pipeline_favicon_status(_, _), do: "pending"

  def pipeline_status(pipeline, path),
    do: pipeline_status(pipeline.state, pipeline.result, path)

  def pipeline_status(:INITIALIZING, _, path),
    do:
      "<a href='#{path}' class='link db flex-shrink-0 f6 br2 w3 tc white mr2 ba bg-orange'>Pending</a>"

  def pipeline_status(:PENDING, _, path),
    do:
      "<a href='#{path}' class='link db flex-shrink-0 f6 br2 w3 tc white mr2 ba bg-orange'>Pending</a>"

  def pipeline_status(:QUEUING, _, path),
    do:
      "<a href='#{path}' class='link db flex-shrink-0 f6 br2 w3 tc white mr2 ba bg-orange'>Queuing</a>"

  def pipeline_status(:RUNNING, _, path),
    do:
      "<a href='#{path}' class='link db flex-shrink-0 f6 br2 w3 tc white mr2 ba bg-indigo'>Running</a>"

  def pipeline_status(:STOPPING, _, path),
    do:
      "<a href='#{path}' class='link db flex-shrink-0 f6 br2 w3 tc white mr2 ba bg-indigo'>Stopping</a>"

  def pipeline_status(:DONE, :PASSED, path),
    do:
      "<a href='#{path}' class='link db flex-shrink-0 f6 br2 w3 tc white mr2 ba bg-green'>Passed</a>"

  def pipeline_status(:DONE, :FAILED, path),
    do:
      "<a href='#{path}' class='link db flex-shrink-0 f6 br2 w3 tc white mr2 ba bg-red'>Failed</a>"

  def pipeline_status(:DONE, :STOPPED, path),
    do:
      "<a href='#{path}' class='link db flex-shrink-0 f6 br2 w3 tc white mr2 ba bg-gray'>Stopped</a>"

  def pipeline_status(:DONE, :CANCELED, path),
    do:
      "<a href='#{path}' class='link db flex-shrink-0 f6 br2 w3 tc white mr2 ba bg-gray'>Canceled</a>"

  def pipeline_running_state(:RUNNING),
    do: "run"

  def pipeline_running_state(_),
    do: ""

  def pipeline_duration(pipeline),
    do: pipeline_duration(pipeline, pipeline.state, pipeline.result)

  def pipeline_duration(_pipeline, :INITIALIZING, _),
    do: "00:00"

  def pipeline_duration(_pipeline, :PENDING, _),
    do: "00:00"

  def pipeline_duration(_pipeline, :QUEUING, _),
    do: "00:00"

  def pipeline_duration(pipeline, :RUNNING, _),
    do: pipeline_duration_time(pipeline)

  def pipeline_duration(pipeline, :STOPPING, _),
    do: pipeline_duration_time(pipeline)

  def pipeline_duration(pipeline, :DONE, :PASSED),
    do: pipeline_duration_time(pipeline)

  def pipeline_duration(pipeline, :DONE, :FAILED),
    do: pipeline_duration_time(pipeline)

  def pipeline_duration(pipeline, :DONE, :STOPPED),
    do: pipeline_duration_time(pipeline)

  def pipeline_duration(pipeline, :DONE, :CANCELED),
    do: pipeline_duration_time(pipeline)

  def pipeline_duration_seconds(pipeline) do
    FrontWeb.SharedView.total_seconds(
      pipeline.timeline.running_at,
      pipeline.timeline.done_at
    )
  end

  def pipeline_duration_time(pipeline) do
    pipeline
    |> pipeline_duration_seconds
    |> Front.DurationFormatter.format()
  end

  def pipeline_status_large(pipeline),
    do: pipeline_status_large(pipeline.state, pipeline.result)

  def pipeline_status_large(:INITIALIZING, _),
    do: "<div class='flex-shrink-0 f6 br2 lh-copy w3 tc white mr2 ba bg-orange'>Pending</div>"

  def pipeline_status_large(:PENDING, _),
    do: "<div class='flex-shrink-0 f6 br2 lh-copy w3 tc white mr2 ba bg-orange'>Pending</div>"

  def pipeline_status_large(:QUEUING, _),
    do: "<div class='flex-shrink-0 f6 br2 lh-copy w3 tc white mr2 ba bg-orange'>Queuing</div>"

  def pipeline_status_large(:RUNNING, _),
    do: "<div class='flex-shrink-0 f6 br2 lh-copy w3 tc white mr2 ba bg-indigo'>Running</div>"

  def pipeline_status_large(:STOPPING, _),
    do: "<div class='flex-shrink-0 f6 br2 lh-copy w3 tc white mr2 ba bg-indigo'>Stopping</div>"

  def pipeline_status_large(:DONE, :PASSED),
    do: "<div class='flex-shrink-0 f6 br2 lh-copy w3 tc white mr2 ba bg-green'>Passed</div>"

  def pipeline_status_large(:DONE, :FAILED),
    do: "<div class='flex-shrink-0 f6 br2 lh-copy w3 tc white mr2 ba bg-red'>Failed</div>"

  def pipeline_status_large(:DONE, :STOPPED),
    do: "<div class='flex-shrink-0 f6 br2 lh-copy w3 tc white mr2 ba bg-gray'>Stopped</div>"

  def pipeline_status_large(:DONE, :CANCELED),
    do: "<div class='flex-shrink-0 f6 br2 lh-copy w3 tc white mr2 ba bg-gray'>Canceled</div>"

  def pipeline_timer_color(pipeline), do: pipeline_timer_color(pipeline.state, pipeline.result)

  def pipeline_timer_color(:INITIALIZING, _), do: "orange"

  def pipeline_timer_color(:PENDING, _), do: "orange"

  def pipeline_timer_color(:QUEUING, _), do: "orange"

  def pipeline_timer_color(:RUNNING, _), do: "indigo"

  def pipeline_timer_color(:STOPPING, _), do: "indigo"

  def pipeline_timer_color(:DONE, :PASSED), do: "green"

  def pipeline_timer_color(:DONE, :FAILED), do: "red"

  def pipeline_timer_color(:DONE, :STOPPED), do: "gray"

  def pipeline_timer_color(:DONE, :CANCELED), do: "gray"

  def pipeline_stoppable?(pipeline) do
    pipeline.state != :DONE && pipeline.state != :STOPPING
  end

  def pipeline_rebuildable?(pipeline) do
    pipeline.state == :DONE && pipeline.result != :PASSED
  end

  def anonymous?(conn) do
    conn.assigns.anonymous
  end

  def format_triggerer(conn, workflow, pipeline) do
    # If we don't have a triggerer, we format the action in an old way.
    # We should remove this check eventually
    Map.get(pipeline, :triggerer, :none)
    |> case do
      :none ->
        Logger.warn("Pipeline #{pipeline.id} has no triggerer")
        action_string(conn, workflow, pipeline)

      triggerer ->
        [
          format_trigger_type(conn, triggerer),
          format_triggered_by(conn, triggerer, workflow),
          format_owner(conn, triggerer),
          format_terminator(conn, triggerer)
        ]
        |> Enum.filter(&(&1 != ""))
        |> Enum.join(" ")
    end
  end

  defp format_triggered_by(conn, triggerer, workflow) do
    triggerer.triggered_by
    |> case do
      {:workflow, workflow_id} ->
        link("Workflow", to: workflow_path(conn, :show, workflow_id))
        |> raw_safe_string()

      {:pipeline, pipeline_id} ->
        link("Pipeline",
          to: workflow_path(conn, :show, workflow.id, pipeline_id: pipeline_id)
        )
        |> raw_safe_string()

      {:task, {task_id, _}} ->
        link("Task",
          to: schedulers_path(conn, :show, workflow.project_name, task_id)
        )
        |> raw_safe_string()

      _ ->
        ""
    end
  end

  defp format_terminator(_conn, triggerer) do
    if triggerer.is_terminated? do
      case triggerer.terminated_by do
        {:user, _} = user ->
          "- Stopped by #{format_user(user)}"

        {:name, _} = user ->
          "- Stopped by #{format_user(user)}"

        _ ->
          "- Stopped"
      end
    else
      ""
    end
  end

  defp format_owner(_conn, triggerer) do
    triggerer.owner
    |> case do
      {:user, _} = user ->
        "by #{format_user(user)}"

      {:name, _} = user ->
        "by #{format_user(user)}"

      _ ->
        ""
    end
  end

  defp format_user(user) do
    user
    |> case do
      {:user, {_user_id, ""}} ->
        "[Deleted User]"

      {:user, {_user_id, user_name}} ->
        escape_unsafe_string(user_name)

      {:name, name} ->
        escape_unsafe_string(name)

      _ ->
        "N/A"
    end
  end

  @spec format_trigger_type(any(), Front.Models.Pipeline.Triggerer.t()) :: String.t()
  defp format_trigger_type(_conn, triggerer) do
    case triggerer.trigger_type do
      :INITIAL_WORKFLOW ->
        "Triggered by push"

      :WORKFLOW_RERUN ->
        "Triggered by rerun of a"

      :API ->
        "Triggered by API call"

      :SCHEDULED_RUN ->
        "Scheduled run of a"

      :SCHEDULED_MANUAL_RUN ->
        "Manual run of a"

      :PIPELINE_PARTIAL_RERUN ->
        "Partial rerun of a"

      :MANUAL_PROMOTION ->
        "Manual promotion"

      :AUTO_PROMOTION ->
        "Auto promoted"
    end
  end

  def action_string(conn, workflow, pipeline) do
    cond do
      pipeline.terminated_by != "" ->
        action_string(:terminated, conn, workflow, pipeline)

      pipeline.partial_rerun_of != "" ->
        action_string(:partial_rerun_of, conn, workflow, pipeline)

      Map.has_key?(pipeline, :origin) ->
        action_string(:promotion, conn, workflow, pipeline)

      workflow.rerun_of != "" ->
        action_string(:rerun_of, conn, workflow, pipeline)

      true ->
        action_string(:trigger, conn, workflow, pipeline)
    end
  end

  def action_string(:terminated, _conn, _workflow, pipeline) do
    cond do
      pipeline.terminator ->
        "Stopped by #{escape_unsafe_string(pipeline.terminator.name)}"

      pipeline.terminated_by == "branch deletion" ->
        "Stopped by branch deletion"

      pipeline.terminated_by == "admin" ->
        "Stopped by Semaphore"

      true ->
        "Stopped"
    end
  end

  def action_string(:promotion, _conn, _workflow, pipeline) do
    if Map.has_key?(pipeline, :promoted_by) do
      "Promoted by #{pipeline.promoted_by.name}"
      |> escape_unsafe_string()
    else
      "Auto-Promoted"
    end
  end

  def action_string(:partial_rerun_of, conn, workflow, pipeline) do
    link =
      link("Pipeline",
        to: workflow_path(conn, :show, workflow.id, pipeline_id: pipeline.partial_rerun_of)
      )
      |> raw_safe_string()

    "Triggered by partial rerun of a #{link}"
  end

  def action_string(:rerun_of, conn, workflow, _pipeline) do
    link =
      link("Workflow", to: workflow_path(conn, :show, workflow.rerun_of))
      |> raw_safe_string()

    "Triggered by rerun of a #{link} #{by_requester_info(workflow)}"
  end

  def action_string(:trigger, _conn, workflow, _pipeline) do
    case workflow.triggered_by do
      :HOOK ->
        "Triggered by push by #{escape_unsafe_string(workflow.hook.repo_host_username)}"

      :SCHEDULE ->
        "Triggered by scheduler"

      :API ->
        "Triggered call to API #{by_requester_info(workflow)}"

      :MANUAL_RUN ->
        "Triggered manually #{by_requester_info(workflow)}"
    end
  end

  defp by_requester_info(workflow) do
    Map.get(workflow, :requester)
    |> case do
      %{name: name} = _requester ->
        "by #{name}"
        |> escape_unsafe_string()

      nil ->
        ""
    end
  end

  def pipeline_status_color(pipeline), do: pipeline_status_color(pipeline.state, pipeline.result)
  def pipeline_status_color(:INITIALIZING, _), do: "orange"
  def pipeline_status_color(:PENDING, _), do: "orange"
  def pipeline_status_color(:QUEUING, _), do: "orange"
  def pipeline_status_color(:RUNNING, _), do: "indigo"
  def pipeline_status_color(:STOPPING, _), do: ""
  def pipeline_status_color(:DONE, :PASSED), do: "green"
  def pipeline_status_color(:DONE, :FAILED), do: "red"
  def pipeline_status_color(:DONE, :STOPPED), do: ""
  def pipeline_status_color(:DONE, :CANCELED), do: ""

  def pipeline_status_text(pipeline), do: pipeline_status_text(pipeline.state, pipeline.result)
  def pipeline_status_text(:INITIALIZING, _), do: "Enqueued"
  def pipeline_status_text(:PENDING, _), do: "Enqueued"
  def pipeline_status_text(:QUEUING, _), do: "Enqueued"
  def pipeline_status_text(:RUNNING, _), do: "Running..."
  def pipeline_status_text(:STOPPING, _), do: "Stopping..."
  def pipeline_status_text(:DONE, :PASSED), do: "Passed"
  def pipeline_status_text(:DONE, :FAILED), do: "Failed"
  def pipeline_status_text(:DONE, :STOPPED), do: "Stopped"
  def pipeline_status_text(:DONE, :CANCELED), do: "Canceled"

  def pipeline_status_badge(pipeline), do: pipeline_status_badge(pipeline.state, pipeline.result)

  def pipeline_status_badge(:INITIALIZING, _),
    do: "<span class='bg-gray white br1 pv1 ph2'>Pending</span>"

  def pipeline_status_badge(:QUEUING, _),
    do: "<span class='bg-gray white br1 pv1 ph2'>Enqueued</span>"

  def pipeline_status_badge(:PENDING, _),
    do: "<span class='bg-gray white br1 pv1 ph2'>Pending</span>"

  def pipeline_status_badge(:RUNNING, _), do: "<span class='badge badge-running'>Running…</span>"

  def pipeline_status_badge(:STOPPING, _),
    do: "<span class='bg-gray white br1 pv1 ph2'>Stopping</span>"

  def pipeline_status_badge(:DONE, :PASSED), do: "<span class='badge badge-passed'>Passed</span>"
  def pipeline_status_badge(:DONE, :FAILED), do: "<span class='badge badge-failed'>Failed</span>"

  def pipeline_status_badge(:DONE, :STOPPED),
    do: "<span class='bg-gray white br1 pv1 ph2'>Stopped</span>"

  # this should never happen
  def pipeline_status_badge(_, _), do: ""

  def pipeline_status_icon_name(:INITIALIZING, _), do: "icn-not-started"
  def pipeline_status_icon_name(:PENDING, _), do: "icn-not-started"
  def pipeline_status_icon_name(:QUEUING, _), do: "icn-enqueued"
  def pipeline_status_icon_name(:RUNNING, _), do: "icn-running"
  def pipeline_status_icon_name(:STOPPING, _), do: "icn-not-started"
  def pipeline_status_icon_name(:DONE, :PASSED), do: "icn-passed"
  def pipeline_status_icon_name(:DONE, :FAILED), do: "icn-failed"
  def pipeline_status_icon_name(:DONE, :STOPPED), do: "icn-stopped"
  def pipeline_status_icon_name(:DONE, :CANCELED), do: "icn-skipped"

  def job_status_color(job), do: job_status_color(job.state, job.result)
  def job_status_color(:ENQUEUED, _), do: "light-gray"
  def job_status_color(:RUNNING, _), do: "indigo"
  def job_status_color(:STOPPING, _), do: "gray"
  def job_status_color(:FINISHED, :PASSED), do: "green"
  def job_status_color(:FINISHED, :STOPPED), do: "gray"
  def job_status_color(:FINISHED, :FAILED), do: "red"

  def nodes(blocks, conn) do
    blocks
    |> Enum.map(fn block ->
      %{
        name: block.name,
        skipped: block.skipped?,
        html:
          render(FrontWeb.PipelineView, "_block.html", block: block, conn: conn)
          |> elem(1)
          |> Enum.join("")
      }
    end)
  end

  def edges(blocks) do
    blocks
    |> Enum.map(fn dependent_block ->
      dependent_block.dependencies
      |> Enum.map(fn dependency_name ->
        %{source: dependency_name, target: dependent_block.name, color: "#98a9a9"}
      end)
    end)
    |> List.flatten()
  end

  def indirect_edges(blocks) do
    blocks
    |> Enum.map(fn dependent_block ->
      dependent_block.indirect_dependencies
      |> Enum.map(fn dependency_name ->
        %{source: dependency_name, target: dependent_block.name, color: "#98a9a9"}
      end)
    end)
    |> List.flatten()
  end

  def deployment_message(conn, deployment) do
    link_to_deployment =
      Phoenix.HTML.Link.link(deployment.name,
        to: deployments_path(conn, :index, conn.assigns.project.name)
      )

    replacement = safe_to_string(link_to_deployment) <> " Deployment Target"
    String.replace(deployment.message, "%{deployment_target}", replacement)
  end

  def pipeline_poll_state(pipeline) do
    if pipeline.state == :DONE do
      pipeline
      |> Map.get(:after_task, %{})
      |> Map.get(:jobs, [])
      |> case do
        nil -> []
        other -> other
      end
      |> Enum.reduce(true, fn job, all_done? ->
        all_done? && job.done?
      end)
      |> case do
        true -> "done"
        _ -> "poll"
      end
    else
      "poll"
    end
  end

  def pipeline_poll_initialized_state(pipeline) do
    if pipeline.state != :INITIALIZING do
      pipeline
      |> Map.get(:after_task, %{})
      |> Map.get(:jobs, [])
      |> case do
        nil -> []
        other -> other
      end
      |> Enum.reduce(true, fn job, all_done? ->
        all_done? && job.done?
      end)
      |> case do
        true -> "done"
        _ -> "poll"
      end
    else
      "poll"
    end
  end

  def timer_action(pipeline) do
    if pipeline.state == :RUNNING do
      "run"
    end
  end

  def job_total_time(job) do
    cond do
      job.state == :RUNNING ->
        :os.system_time(:seconds) - job.started_at.seconds

      job.state == :FINISHED && job.started_at ->
        job.finished_at.seconds - job.started_at.seconds

      true ->
        0
    end
  end

  def job_data(job, conn) do
    if conn.assigns.organization_id in [] || Application.get_env(:front, :environment) == :dev do
      [action: "triggerJobModal", id: job.id]
    else
      []
    end
  end

  def child_pipeline_id(pipeline) do
    if pipeline && pipeline.switch && pipeline.switch.pipeline do
      pipeline.switch.pipeline.id
    else
      nil
    end
  end

  def with_after_task(pipeline) do
    pipeline
    |> Map.get(:after_task, %{})
    |> Map.get(:present?, false)
  end

  def with_switch(nil), do: false
  def with_switch(%{switch: nil}), do: false
  def with_switch(_), do: true

  def run_pipeline?(pipeline) do
    if pipeline.state == :RUNNING, do: "run"
  end

  def total_seconds(pipeline) do
    FrontWeb.SharedView.total_seconds(pipeline.timeline.running_at, pipeline.timeline.done_at)
  end

  def total_time(pipeline) do
    FrontWeb.SharedView.total_time(pipeline.timeline.running_at, pipeline.timeline.done_at)
  end

  def color_class(pipeline) do
    pipeline_timer_color(pipeline)
  end
end
