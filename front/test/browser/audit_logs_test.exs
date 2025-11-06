defmodule Front.Browser.AuditLogsTest do
  use FrontWeb.WallabyCase

  alias Support.Stubs

  import Wallaby.Query, only: [link: 1]

  browser_test "viewing audit logs that have project details", %{session: session} do
    user = Stubs.User.create_default()
    org = Stubs.Organization.create_default()
    Support.Stubs.Feature.enable_feature(org.id, :audit_logs)
    Support.Stubs.Feature.enable_feature(org.id, :permission_patrol)
    Support.Stubs.PermissionPatrol.allow_everything(org.id, user.id)
    project = Stubs.Project.create(org, user)

    Stubs.AuditLog.add_event(:Project, :Modified, %{
      resource_name: "front",
      description: "Changed name from front to hello",
      metadata: Poison.encode!(%{"project_id" => project.id})
    })

    page = open(session)

    assert_text(page, "Project:")
    assert_text(page, project.name)
  end

  describe "viewing audit for promotions" do
    setup do
      user = Stubs.User.create_default()
      org = Stubs.Organization.create_default()
      Support.Stubs.Feature.enable_feature(org.id, :audit_logs)
      Support.Stubs.Feature.enable_feature(org.id, :permission_patrol)

      Support.Stubs.PermissionPatrol.add_permissions(org.id, user.id, [
        "organization.view",
        "organization.audit_logs.view",
        "organization.audit_logs.manage"
      ])

      project = Stubs.Project.create(org, user)
      branch = Stubs.Branch.create(project)
      hook = Stubs.Hook.create(branch)
      workflow = Stubs.Workflow.create(hook, user)

      pipeline =
        Stubs.Pipeline.create_initial(workflow, name: "Build & Test", organization_id: org.id)

      switch = Stubs.Pipeline.add_switch(pipeline)
      Stubs.Switch.add_target(switch, name: "Production")

      description = "Triggered a promotion to Production"

      Stubs.AuditLog.add_event(:Pipeline, :Promoted, %{
        resource_name: "Production",
        description: description,
        metadata:
          Poison.encode!(%{
            "project_id" => project.id,
            "workflow_id" => workflow.id,
            "pipeline_id" => pipeline.id
          })
      })

      Stubs.AuditLog.add_event(:SelfHostedAgent, :Added, %{
        resource_name: "my-agent",
        description: "Self-hosted agent registered",
        metadata:
          Poison.encode!(%{
            "agent_type_name" => "s1-local-testing",
            "ip_address" => "123.45.67.89"
          })
      })

      {:ok,
       %{
         project: project,
         branch: branch,
         hook: hook,
         workflow: workflow,
         pipeline: pipeline,
         description: description
       }}
    end

    browser_test "project link is displayed", %{session: session, project: project} do
      page = open(session)

      assert_text(page, "Project:")
      assert_text(page, project.name)

      click(page, link(project.name))

      assert Wallaby.Browser.current_path(page) == "/projects/#{project.name}"
    end

    browser_test "branch link is displayed", %{session: session, branch: branch} do
      page = open(session)

      assert_text(page, "Branch:")
      assert_text(page, branch.name)

      click(page, link(branch.name))

      assert Wallaby.Browser.current_path(page) == "/branches/#{branch.id}"
    end

    browser_test "workflow link is displayed", %{session: session, workflow: workflow, hook: hook} do
      page = open(session)

      assert_text(page, "Workflow:")
      assert_text(page, hook.api_model.commit_message)

      click(page, link(hook.api_model.commit_message))

      assert Wallaby.Browser.current_path(page) == "/workflows/#{workflow.id}"
    end

    browser_test "pipeline link is displayed", %{
      session: session,
      workflow: workflow,
      pipeline: pipeline
    } do
      page = open(session)

      assert_text(page, "Pipeline:")
      assert_text(page, pipeline.api_model.name)

      click(page, link(pipeline.api_model.name))

      assert Wallaby.Browser.current_path(page) == "/workflows/#{workflow.id}"
    end

    browser_test "event description is visible", %{session: session} do
      page = open(session)

      assert_text(page, "Triggered a promotion to Production")
    end

    browser_test "agent name and IP address is visible", %{session: session} do
      page = open(session)

      assert_text(page, "s1-local-testing")
      assert_text(page, "123.45.67.89")
    end
  end

  defp open(session) do
    session |> visit("/audit")
  end
end
