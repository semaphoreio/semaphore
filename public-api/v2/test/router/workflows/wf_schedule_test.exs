defmodule Router.Workflows.ScheduleTest do
  use PublicAPI.Case

  describe "naive authorization filter with default allowed users" do
    setup do
      Support.Stubs.reset()
      project_id = UUID.uuid4()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      Support.Stubs.Project.create(%{id: org_id}, %{id: user_id}, id: project_id)

      PermissionPatrol.add_permissions(org_id, user_id, "project.job.rerun", project_id)

      {:ok, %{project_id: project_id, org_id: org_id, user_id: user_id}}
    end

    test "POST /workflows/ - successfull when server returns :OK response", ctx do
      params = %{
        "project_id" => ctx.project_id,
        "reference" => "master",
        "commit_sha" => "1234",
        "pipeline_file" => ".semaphore/semaphore.yml"
      }

      assert {:ok, response} = create_workflow(ctx, params, 200)

      assert {:ok, _} = UUID.info(response["wf_id"])
      assert {:ok, _} = UUID.info(response["ppl_id"])
      assert {:ok, _} = UUID.info(response["hook_id"])
    end

    test "POST /workflows/ - returns 422 when invalid data in request", ctx do
      params = %{
        "project_id" => "invalid-argument",
        "reference" => "master",
        "commit_sha" => "failed_precondition",
        "pipeline_file" => ".semaphore/semaphore.yml"
      }

      assert {:ok, message} = create_workflow(ctx, params, 422)
      assert %{"message" => "Validation Failed"} = message
    end

    test "POST /workflows/ - returns 400 when server returns :invalid_argument response", ctx do
      params = %{
        "project_id" => ctx.project_id,
        "reference" => "master",
        "commit_sha" => "invalid_arg",
        "pipeline_file" => ".semaphore/semaphore.yml"
      }

      assert {:ok, message} = create_workflow(ctx, params, 400)
      assert %{"message" => "Invalid argument"} = message
    end

    test "POST /workflows/ - returns 400 when server returns :not_found response", ctx do
      params = %{
        "project_id" => ctx.project_id,
        "reference" => "master",
        "commit_sha" => "not_found",
        "pipeline_file" => ".semaphore/semaphore.yml",
        "kk" => "kk"
      }

      assert {:ok, message} = create_workflow(ctx, params, 400)
      assert %{"message" => "Not found"} = message
    end

    test "POST /workflows/ - returns 400 when server returns :aborted response", ctx do
      params = %{
        "project_id" => ctx.project_id,
        "reference" => "master",
        "commit_sha" => "aborted",
        "pipeline_file" => ".semaphore/semaphore.yml"
      }

      assert {:ok, message} = create_workflow(ctx, params, 400)
      assert %{"message" => "Aborted"} = message
    end

    test "POST /workflows/ - returns 500 when there is an internal error on server", ctx do
      System.put_env("REPO_PROXY_URL", "something:12345")

      params = %{
        "project_id" => ctx.project_id,
        "reference" => "master",
        "commit_sha" => "1234",
        "pipeline_file" => ".semaphore/semaphore.yml"
      }

      assert {:ok, message} = create_workflow(ctx, params, 500)
      assert %{"message" => "Internal error"} = message

      System.put_env("REPO_PROXY_URL", "127.0.0.1:50052")
    end
  end

  def create_workflow(ctx, params, expected_status_code) do
    {:ok, response} = params |> Jason.encode!() |> create(ctx)
    %{:body => body, :status_code => status_code} = response
    if(status_code != 200, do: IO.puts("Response body: #{inspect(body)}"))
    assert status_code == expected_status_code
    body |> Jason.decode()
  end

  defp create(body, ctx) do
    HTTPoison.post(url() <> "/workflows", body, headers(ctx))
  end
end
