defmodule FrontWeb.ProjectView do
  use FrontWeb, :view

  def star_tippy_content(true), do: "Unstar this project"
  def star_tippy_content(false), do: "Star this project"

  def navigation_element_style(link_name, highlighted_element) do
    link_name_atom =
      link_name
      |> String.downcase()
      |> String.replace(" ", "_")
      |> String.to_atom()

    if link_name_atom == highlighted_element do
      "tab-active"
    end
  end

  def description(""), do: ""
  def description(nil), do: ""
  def description(description), do: " · #{description}"

  def show_pagination?(pagination) do
    !((pagination.on_first_page && pagination.on_last_page) || pagination.no_pages)
  end

  def branch_state_inline_class(pipeline) do
    case {pipeline.state, pipeline.result} do
      {:DONE, :PASSED} -> "green"
      {:DONE, :FAILED} -> "red"
      {:DONE, :CANCELED} -> "black"
      {:DONE, :STOPPED} -> "black"
      {:RUNNING, _} -> "indigo"
      {:STOPPING, _} -> "indigo"
      _ -> "orange"
    end
  end

  def poll_state(pagination) do
    case pagination.page do
      1 -> "poll"
      _ -> "done"
    end
  end

  def empty_list_icon("branch") do
    """
    <svg viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg"><path d="m5 7h4c1.1045695 0 2-.8954305 2-2v-.26756439c-.5978014-.34580942-1-.99215325-1-1.73243561 0-1.1045695.8954305-2 2-2s2 .8954305 2 2c0 .74028236-.4021986 1.38662619-1 1.73243561v.26756439c0 2.209139-1.790861 4-4 4h-4v2.2675644c.59780137.3458094 1 .9921532 1 1.7324356 0 1.1045695-.8954305 2-2 2s-2-.8954305-2-2c0-.7402824.40219863-1.3866262 1-1.7324356v-6.53512879c-.59780137-.34580942-1-.99215325-1-1.73243561 0-1.1045695.8954305-2 2-2s2 .8954305 2 2c0 .74028236-.40219863 1.38662619-1 1.73243561z" fill-rule="evenodd" fill="#97A4A4"></path></svg>
    """
  end

  def empty_list_icon("pr") do
    """
    <svg viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg"><path d="m9 2h1.440918c1.9631226 0 3.559082 1.59234154 3.559082 3.54929647v5.71826793c.5978014.3458094 1 .9921532 1 1.7324356 0 1.1045695-.8954305 2-2 2s-2-.8954305-2-2c0-.7402824.4021986-1.3866262 1-1.7324356v-5.71826793c0-.85136808-.6995141-1.54929647-1.559082-1.54929647h-1.440918v2l-3-3 3-3zm-7 2.73243561c-.59780137-.34580942-1-.99215325-1-1.73243561 0-1.1045695.8954305-2 2-2s2 .8954305 2 2c0 .74028236-.40219863 1.38662619-1 1.73243561v6.53512879c.59780137.3458094 1 .9921532 1 1.7324356 0 1.1045695-.8954305 2-2 2s-2-.8954305-2-2c0-.7402824.40219863-1.3866262 1-1.7324356z" fill="#97A4A4"></path></svg>
    """
  end

  def empty_list_icon("tag") do
    """
    <svg viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg"><path d="m1.24134968 1.93585709 11.73208142.00415939 3.9034634 2.99603158v4l-3.9034634 3.00396844-11.73208142-.0041594zm11.73208142 6.00415939c.5522848 0 1-.44771525 1-1s-.4477152-1-1-1c-.5522847 0-1 .44771525-1 1s.4477153 1 1 1z" fill-rule="evenodd" transform="matrix(.70710678 -.70710678 .70710678 .70710678 -2.252507 8.437841)" fill="#97A4A4"></path></svg>
    """
  end

  def empty_list_icon(_) do
    """
    <svg viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg"><path d="M9 0L4 9h3l-1 7 5-9H8z" fill-rule="evenodd" fill="#97A4A4"></path></svg>
    """
  end

  def empty_list_copy("branch", project, conn),
    do: empty_list_copy(project.build_branches, "Branches", "Branch", conn, project.name)

  def empty_list_copy("pr", project, conn),
    do:
      empty_list_copy(
        project.build_prs || project.build_forked_prs,
        "Pull Requests",
        "Pull Request",
        conn,
        project.name
      )

  def empty_list_copy("tag", project, conn),
    do: empty_list_copy(project.build_tags, "Tags", "Tag", conn, project.name)

  def empty_list_copy(_, _project, _conn) do
    """
    <p class="f5 gray mb0 measure center">You don't have any workflows yet. If you already have configuration in repository, please push to it and you will see your workflow running here. Otherwise, configure new workflow.</p>
    """
  end

  def empty_list_copy(enabled, plurar, singular, conn, project_name) do
    if enabled do
      empty_list_copy_enabled(plurar, singular)
    else
      empty_list_copy_disabled(plurar, conn, project_name)
    end
  end

  def empty_list_copy_enabled(plurar, singular) do
    """
    <p class="f5 gray mb0">Running workflows for #{plurar} is enabled. Semaphore is waiting for your first #{String.downcase(singular)}.</p>
    """
  end

  def empty_list_copy_disabled(plurar, conn, project_name) do
    if conn.assigns.anonymous do
      """
      <p class="f5 gray mb2">Running workflows for #{plurar} is disabled.</p>
      """
    else
      """
      <p class="f5 gray mb2">Running workflows for #{plurar} is disabled. You can enable them in the&nbsp;<a href="#{project_settings_path(conn, :general, project_name)}">project settings</a>.</p>
      <p class="f5 gray mb0">For more details, see:&nbsp;<a href="https://#{Application.fetch_env!(:front, :docs_domain)}/article/152-project-workflow-trigger-options">Project workflow trigger options</a>.</p>
      """
    end
  end
end
