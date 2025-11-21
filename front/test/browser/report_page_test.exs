defmodule Front.Browser.ReportPageTest do
  use FrontWeb.WallabyCase

  alias Support.Browser.WorkflowPage
  alias Support.Stubs.DB

  setup do
    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    :ok
  end

  describe "when ui_reports feature is disabled" do
    setup %{session: session} do
      context = WorkflowPage.create_workflow()

      Support.Stubs.Feature.disable_feature(context.org.id, :ui_reports)

      Support.Stubs.PermissionPatrol.allow_everything(
        context.org.id,
        context.workflow.api_model.requester_id
      )

      %{session: session, workflow: context.workflow, org: context.org, project: context.project}
    end

    browser_test "does not display a report tab on worklfow page", %{
      session: session,
      workflow: workflow
    } do
      session
      |> visit("/workflows/#{workflow.id}")
      |> refute_has(Query.text("Report"))
    end

    browser_test "does not display a report tab on a job page", %{
      session: session
    } do
      job_id =
        DB.first(:jobs)
        |> Map.get(:id)

      session
      |> visit("/jobs/#{job_id}")
      |> refute_has(Query.text("Report"))
    end

    browser_test "does not display a report tab on a project page", %{
      session: session
    } do
      project_name =
        DB.first(:projects)
        |> Map.get(:name)

      session
      |> visit("/projects/#{project_name}")
      |> refute_has(Query.text("Report"))
    end
  end

  describe "when ui_reports feature is enabled" do
    setup %{session: session} do
      context = WorkflowPage.create_workflow()

      Support.Stubs.Feature.enable_feature(context.org.id, :ui_reports)

      Support.Stubs.PermissionPatrol.allow_everything(
        context.org.id,
        context.workflow.api_model.requester_id
      )

      %{session: session, workflow: context.workflow, org: context.org, project: context.project}
    end

    browser_test "displays a report tab on a workflow page", %{
      session: session,
      workflow: workflow
    } do
      session
      |> visit("/workflows/#{workflow.id}")
      |> assert_has(Query.text("Report"))
    end

    browser_test "displays a report tab on a job page", %{
      session: session
    } do
      job_id =
        DB.first(:jobs)
        |> Map.get(:id)

      session
      |> visit("/jobs/#{job_id}")
      |> assert_has(Query.text("Report"))
    end

    browser_test "displays a report tab on a project page", %{
      session: session
    } do
      project_name =
        DB.first(:projects)
        |> Map.get(:name)

      session
      |> visit("/projects/#{project_name}")
      |> assert_has(Query.text("Report"))
    end
  end
end
