defmodule FrontWeb.PipelineControllerTest do
  use FrontWeb.ConnCase
  alias Support.Stubs.DB

  setup %{conn: conn} do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    Support.Stubs.PermissionPatrol.allow_everything()

    workflow_id = DB.first(:workflows) |> Map.get(:id)
    pipeline_id = DB.first(:pipelines) |> Map.get(:id)

    [
      conn: conn,
      workflow_id: workflow_id,
      pipeline_id: pipeline_id
    ]
  end

  def prepare_pipeline(_context) do
    alias Support.Stubs
    Stubs.init()
    user = Stubs.User.create_default()
    org = Stubs.Organization.create_default()
    project = Stubs.Project.create(org, user)
    branch = Stubs.Branch.create(project)

    hook = Stubs.Hook.create(branch)
    workflow = Stubs.Workflow.create(hook, user)

    pipeline =
      Stubs.Pipeline.create_initial(workflow, name: "Build & Test", organization_id: org.id)

    Stubs.Pipeline.add_blocks(pipeline, [
      %{name: "Block 1"},
      %{name: "Block 2", dependencies: ["Block 1"]},
      %{name: "Block 3", dependencies: ["Block 1"]}
    ])

    switch = Stubs.Pipeline.add_switch(pipeline)
    Stubs.Switch.add_target(switch, name: "Production")
    Stubs.Switch.add_target(switch, name: "Staging")

    [ppl_id: pipeline.id, wf_id: workflow.id]
  end

  describe "path" do
    test "returns 200 for authorized requests", %{
      conn: conn,
      workflow_id: workflow_id,
      pipeline_id: pipeline_id
    } do
      conn =
        conn
        |> get("/workflows/#{workflow_id}/pipelines/#{pipeline_id}/path")

      assert conn.status == 200
    end

    test "returns 404 when organization_id mismatches", %{
      conn: conn,
      workflow_id: workflow_id,
      pipeline_id: pipeline_id
    } do
      conn =
        conn
        |> Plug.Conn.put_req_header("x-semaphore-org-id", Ecto.UUID.generate())
        |> get("/workflows/#{workflow_id}/pipelines/#{pipeline_id}/path")

      assert conn.status == 404
    end
  end

  describe "stop" do
    test "sends terminate request", %{
      conn: conn,
      workflow_id: workflow_id,
      pipeline_id: pipeline_id
    } do
      conn =
        conn
        |> post("/workflows/#{workflow_id}/pipelines/#{pipeline_id}/stop")

      assert conn.status == 200
    end

    test "returns 404 when organization_id mismatches", %{
      conn: conn,
      workflow_id: workflow_id,
      pipeline_id: pipeline_id
    } do
      conn =
        conn
        |> Plug.Conn.put_req_header("x-semaphore-org-id", Ecto.UUID.generate())
        |> post("/workflows/#{workflow_id}/pipelines/#{pipeline_id}/stop")

      assert conn.status == 404
    end
  end

  describe "status" do
    test "is correct when pipeline is in pending state", %{
      conn: conn,
      workflow_id: workflow_id,
      pipeline_id: pipeline_id
    } do
      conn =
        conn
        |> get("/workflows/#{workflow_id}/pipelines/#{pipeline_id}/status")

      assert conn.status == 200
      assert conn.resp_body == "pending"
    end

    test "returns 404 when organization_id mismatches", %{
      conn: conn,
      workflow_id: workflow_id,
      pipeline_id: pipeline_id
    } do
      conn =
        conn
        |> Plug.Conn.put_req_header("x-semaphore-org-id", Ecto.UUID.generate())
        |> get("/workflows/#{workflow_id}/pipelines/#{pipeline_id}/status")

      assert conn.status == 404
    end

    test "is correct when pipeline is in running state", %{
      conn: conn,
      workflow_id: workflow_id,
      pipeline_id: pipeline_id
    } do
      Support.Stubs.Pipeline.change_state(pipeline_id, :running)

      conn =
        conn
        |> get("/workflows/#{workflow_id}/pipelines/#{pipeline_id}/status")

      assert conn.status == 200
      assert conn.resp_body == "running"
    end

    test "is correct when pipeline is in stopped state", %{
      conn: conn,
      workflow_id: workflow_id,
      pipeline_id: pipeline_id
    } do
      Support.Stubs.Pipeline.change_state(pipeline_id, :stopped)

      conn =
        conn
        |> get("/workflows/#{workflow_id}/pipelines/#{pipeline_id}/status")

      assert conn.status == 200
      assert conn.resp_body == "stopped"
    end

    test "is correct when pipeline is in failed state", %{
      conn: conn,
      workflow_id: workflow_id,
      pipeline_id: pipeline_id
    } do
      Support.Stubs.Pipeline.change_state(pipeline_id, :failed)

      conn =
        conn
        |> get("/workflows/#{workflow_id}/pipelines/#{pipeline_id}/status")

      assert conn.status == 200
      assert conn.resp_body == "failed"
    end

    test "is correct when pipeline is in passed state", %{
      conn: conn,
      workflow_id: workflow_id,
      pipeline_id: pipeline_id
    } do
      Support.Stubs.Pipeline.change_state(pipeline_id, :passed)

      conn =
        conn
        |> get("/workflows/#{workflow_id}/pipelines/#{pipeline_id}/status")

      assert conn.status == 200
      assert conn.resp_body == "passed"
    end

    test "is correct when pipeline is in stopping state", %{
      conn: conn,
      workflow_id: workflow_id,
      pipeline_id: pipeline_id
    } do
      Support.Stubs.Pipeline.change_state(pipeline_id, :stopping)

      conn =
        conn
        |> get("/workflows/#{workflow_id}/pipelines/#{pipeline_id}/status")

      assert conn.status == 200
      assert conn.resp_body == "stopping"
    end

    test "is correct when pipeline is in canceled state", %{
      conn: conn,
      workflow_id: workflow_id,
      pipeline_id: pipeline_id
    } do
      Support.Stubs.Pipeline.change_state(pipeline_id, :canceled)

      conn =
        conn
        |> get("/workflows/#{workflow_id}/pipelines/#{pipeline_id}/status")

      assert conn.status == 200
      assert conn.resp_body == "canceled"
    end
  end

  describe "show => when request is authenticated" do
    test "returns 200", %{conn: conn, workflow_id: workflow_id, pipeline_id: pipeline_id} do
      conn =
        conn
        |> get("/workflows/#{workflow_id}/pipelines/#{pipeline_id}")

      assert conn.status == 200
    end
  end

  describe "show => when user does not have access to project" do
    test "returns 404", %{conn: conn, workflow_id: workflow_id, pipeline_id: pipeline_id} do
      Support.Stubs.PermissionPatrol.remove_all_permissions()

      org = Support.Stubs.DB.first(:organizations)
      user = Support.Stubs.DB.first(:users)

      Support.Stubs.PermissionPatrol.allow_everything_except(org.id, user.id, "project.view")

      conn =
        conn
        |> get("/workflows/#{workflow_id}/pipelines/#{pipeline_id}")

      assert conn.status == 404
    end
  end

  describe "stop => when user does not have permission to stop jobs" do
    test "returns 404", %{conn: conn, workflow_id: workflow_id, pipeline_id: pipeline_id} do
      Support.Stubs.PermissionPatrol.remove_all_permissions()

      org = Support.Stubs.DB.first(:organizations)
      user = Support.Stubs.DB.first(:users)

      Support.Stubs.PermissionPatrol.allow_everything_except(org.id, user.id, "project.job.stop")

      conn =
        conn
        |> post("/workflows/#{workflow_id}/pipelines/#{pipeline_id}/stop")

      assert conn.status == 404
    end
  end

  describe "rebuild" do
    test "sends partial rebuild request", %{
      conn: conn,
      workflow_id: workflow_id,
      pipeline_id: pipeline_id
    } do
      conn =
        conn
        |> post("/workflows/#{workflow_id}/pipelines/#{pipeline_id}/rebuild")

      assert conn.status == 200
      assert json_response(conn, 200)["message"] == "Pipeline rebuild initiated successfully."
      assert json_response(conn, 200)["pipeline_id"] != nil
    end

    test "returns 404 when organization_id mismatches", %{
      conn: conn,
      workflow_id: workflow_id,
      pipeline_id: pipeline_id
    } do
      conn =
        conn
        |> Plug.Conn.put_req_header("x-semaphore-org-id", Ecto.UUID.generate())
        |> post("/workflows/#{workflow_id}/pipelines/#{pipeline_id}/rebuild")

      assert conn.status == 404
    end
  end

  describe "rebuild => when user does not have permission to rerun jobs" do
    test "returns 404", %{conn: conn, workflow_id: workflow_id, pipeline_id: pipeline_id} do
      Support.Stubs.PermissionPatrol.remove_all_permissions()

      org = Support.Stubs.DB.first(:organizations)
      user = Support.Stubs.DB.first(:users)

      Support.Stubs.PermissionPatrol.allow_everything_except(org.id, user.id, "project.job.rerun")

      conn =
        conn
        |> post("/workflows/#{workflow_id}/pipelines/#{pipeline_id}/rebuild")

      assert conn.status == 404
    end
  end

  describe "rebuild => with ui_partial_ppl_rebuild feature flag" do
    test "returns 404 when feature flag is disabled", %{
      conn: conn,
      workflow_id: workflow_id,
      pipeline_id: pipeline_id
    } do
      org = Support.Stubs.DB.first(:organizations)
      Support.Stubs.Feature.disable_feature(org.id, :ui_partial_ppl_rebuild)

      conn =
        conn
        |> post("/workflows/#{workflow_id}/pipelines/#{pipeline_id}/rebuild")

      assert conn.status == 404
    end

    test "returns 200 when feature flag is enabled", %{
      conn: conn,
      workflow_id: workflow_id,
      pipeline_id: pipeline_id
    } do
      org = Support.Stubs.DB.first(:organizations)
      Support.Stubs.Feature.enable_feature(org.id, :ui_partial_ppl_rebuild)

      conn =
        conn
        |> post("/workflows/#{workflow_id}/pipelines/#{pipeline_id}/rebuild")

      assert conn.status == 200
      assert json_response(conn, 200)["message"] == "Pipeline rebuild initiated successfully."
      assert json_response(conn, 200)["pipeline_id"] != nil
    end
  end
end
