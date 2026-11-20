defmodule FrontWeb.TargetControllerTest do
  use FrontWeb.ConnCase

  alias Support.Factories
  alias Support.Stubs.{DB, PermissionPatrol}

  @user_id "a8114608-be8a-465a-b9cd-81970fb802c6"
  @org_id "78114608-be8a-465a-b9cd-81970fb802c6"

  setup %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_req_header("x-semaphore-user-id", @user_id)
      |> Plug.Conn.put_req_header("x-semaphore-org-id", @org_id)

    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()
    PermissionPatrol.allow_everything(@org_id, @user_id)

    {:ok, %{conn: conn}}
  end

  def ids do
    workflow_id =
      DB.first(:workflows)
      |> Map.get(:id)

    switch_id =
      DB.first(:switches)
      |> Map.get(:id)

    ppl_id =
      DB.first(:pipelines)
      |> Map.get(:id)

    %{workflow: workflow_id, switch: switch_id, pipeline: ppl_id}
  end

  # The static Factories.Gofer.describe_response/0 fixture carries its own
  # unrelated ppl_id. Pin it to the pipeline actually under test so the
  # switch-to-pipeline resolution that TargetController performs succeeds,
  # the same way it would for a switch that genuinely belongs to that
  # pipeline.
  defp describe_response_for(ppl_id) do
    %{Factories.Gofer.describe_response() | ppl_id: ppl_id}
  end

  describe ".trigger" do
    test "when trigger succeeds => it return 200", %{conn: conn} do
      %{workflow: wf_id, pipeline: ppl_id, switch: switch_id} = ids()

      GrpcMock.stub(GoferMock, :describe, describe_response_for(ppl_id))
      GrpcMock.stub(GoferMock, :trigger, Factories.Gofer.succeeded_trigger_response())

      name = URI.encode("Deploy to Prod")

      conn =
        conn
        |> post("/workflows/#{wf_id}/pipelines/#{ppl_id}/swithes/#{switch_id}/targets/#{name}")

      assert conn.status == 200
    end

    test "when user cant run jobs => . returns 404", %{conn: conn} do
      %{workflow: wf_id, pipeline: ppl_id, switch: switch_id} = ids()

      GrpcMock.stub(GoferMock, :describe, describe_response_for(ppl_id))
      GrpcMock.stub(GoferMock, :trigger, Factories.Gofer.succeeded_trigger_response())

      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(@org_id, @user_id, "project.job.rerun")

      name = URI.encode("Deploy to Prod")

      conn =
        conn
        |> post("/workflows/#{wf_id}/pipelines/#{ppl_id}/swithes/#{switch_id}/targets/#{name}")

      assert conn.status == 404
    end

    test "sends the current user as trigger author", %{conn: conn} do
      %{workflow: wf_id, pipeline: ppl_id, switch: switch_id} = ids()

      GrpcMock.stub(GoferMock, :describe, describe_response_for(ppl_id))

      GrpcMock.stub(GoferMock, :trigger, fn request, _ ->
        assert request.triggered_by == "a8114608-be8a-465a-b9cd-81970fb802c6"

        Factories.Gofer.succeeded_trigger_response()
      end)

      name = URI.encode("Deploy to Prod")

      conn =
        conn
        |> post("/workflows/#{wf_id}/pipelines/#{ppl_id}/swithes/#{switch_id}/targets/#{name}")

      assert conn.status == 200
    end

    test "when the target triggering fails => it returns 500", %{conn: conn} do
      %{workflow: wf_id, pipeline: ppl_id, switch: switch_id} = ids()

      GrpcMock.stub(GoferMock, :describe, describe_response_for(ppl_id))
      GrpcMock.stub(GoferMock, :trigger, Factories.Gofer.failed_trigger_response())

      name = URI.encode("Deploy to Prod")

      conn =
        conn
        |> post("/workflows/#{wf_id}/pipelines/#{ppl_id}/swithes/#{switch_id}/targets/#{name}")

      assert conn.status == 500
    end

    test "when the switch belongs to a different pipeline => it returns 404", %{conn: conn} do
      %{workflow: wf_id, pipeline: ppl_id, switch: switch_id} = ids()

      GrpcMock.stub(GoferMock, :describe, describe_response_for("some-other-pipeline-id"))
      GrpcMock.stub(GoferMock, :trigger, Factories.Gofer.succeeded_trigger_response())

      name = URI.encode("Deploy to Prod")

      conn =
        conn
        |> post("/workflows/#{wf_id}/pipelines/#{ppl_id}/swithes/#{switch_id}/targets/#{name}")

      assert conn.status == 404
    end

    test "when the pipeline in the URL belongs to a different workflow => it returns 404", %{
      conn: conn
    } do
      %{pipeline: ppl_id, switch: switch_id} = ids()

      GrpcMock.stub(GoferMock, :describe, describe_response_for(ppl_id))
      GrpcMock.stub(GoferMock, :trigger, Factories.Gofer.succeeded_trigger_response())

      other_workflow = Support.Stubs.Workflow.create(DB.first(:hooks), DB.first(:users))
      name = URI.encode("Deploy to Prod")

      conn =
        conn
        |> post(
          "/workflows/#{other_workflow.id}/pipelines/#{ppl_id}/swithes/#{switch_id}/targets/#{name}"
        )

      assert conn.status == 404
    end
  end
end
