defmodule FrontWeb.DesignBookController do
  use FrontWeb, :controller

  plug(:put_layout, :design_book)

  @workflow_id "6d2f8b90-4a13-4c57-8e2b-9f70c3a5d146"
  @first_attempt_pipeline_id "3f1c9a2e-5b47-4d81-9c06-71ea2f8b4d13"
  @second_attempt_pipeline_id "a72d4e18-6c93-4f52-8b1d-0e5c93a7f264"
  @third_attempt_pipeline_id "c58b7031-2e94-4a6d-b7f8-4d1096e5c832"
  @fourth_attempt_pipeline_id "e91a5d64-7f28-4b03-9e5a-2c86740db19f"
  @promotion_pipeline_id "b40e8c27-9d51-4e76-a8f3-15b9c2704e8a"

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def workspace_data(conn, _params) do
    json(conn, %{
      workflow: workflow(),
      attempts: attempts(),
      current: current()
    })
  end

  defp workflow do
    %{
      id: @workflow_id,
      name: "Reuse passing jobs when rerunning a workflow",
      branch: "main",
      commit: %{
        sha: "4f7c1a93b6e2d580f19c47ab35e8d602c1947fbe",
        message: "Carry forward jobs that already passed",
        author: "sample-user"
      }
    }
  end

  defp attempts do
    [
      %{
        pipeline_id: @first_attempt_pipeline_id,
        index: 1,
        result: "failed",
        failed_blocks: ["Unit tests"],
        duration_ms: 412_000,
        executed_job_count: 8
      },
      %{
        pipeline_id: @second_attempt_pipeline_id,
        index: 2,
        result: "failed",
        failed_blocks: ["Integration tests"],
        duration_ms: 268_000,
        executed_job_count: 5
      },
      %{
        pipeline_id: @third_attempt_pipeline_id,
        index: 3,
        result: "failed",
        failed_blocks: ["Packaging"],
        duration_ms: 154_000,
        executed_job_count: 3
      },
      %{
        pipeline_id: @fourth_attempt_pipeline_id,
        index: 4,
        result: "passed",
        failed_blocks: [],
        duration_ms: 96_000,
        executed_job_count: 4
      }
    ]
  end

  defp current do
    %{
      pipeline_id: @fourth_attempt_pipeline_id,
      blocks: [setup_block(), unit_block(), integration_block(), e2e_block(), packaging_block()],
      promotions: [
        %{
          name: "Deploy to staging",
          status: "passed",
          pipeline_id: @promotion_pipeline_id
        }
      ]
    }
  end

  defp setup_block do
    %{
      name: "Setup",
      result: "passed",
      reused_from: @first_attempt_pipeline_id,
      deps: [],
      jobs: [
        %{
          id: "1b8e4f02-93a7-4c15-8d6e-2f70b591ac48",
          name: "Bootstrap dependency cache",
          result: "passed",
          duration_ms: 74_000,
          original_job_id: "0a5d3c91-7e42-4b68-9f13-8c26074ed5b1",
          executed_in_attempt: 1
        }
      ]
    }
  end

  defp unit_block do
    %{
      name: "Unit tests",
      result: "passed",
      reused_from: nil,
      deps: ["Setup"],
      jobs: [
        %{
          id: "2c9f5013-a4b8-4d26-9e7f-3081c6a2bd59",
          name: "Unit tests 1/2",
          result: "passed",
          duration_ms: 132_000,
          original_job_id: "d7418e26-3b95-4f07-a2c8-6015e94b7d3f",
          executed_in_attempt: 2
        },
        %{
          id: "3da06124-b5c9-4e37-af80-4192d7b3ce6a",
          name: "Unit tests 2/2",
          result: "passed",
          duration_ms: 128_000,
          original_job_id: "e8529f37-4ca6-4018-b3d9-7126fa5c8e40",
          executed_in_attempt: 2
        }
      ]
    }
  end

  defp integration_block do
    %{
      name: "Integration tests",
      result: "passed",
      reused_from: nil,
      deps: ["Setup"],
      jobs: [
        %{
          id: "4eb17235-c6da-4f48-b091-52a3e8c4df7b",
          name: "Integration tests 1/2",
          result: "passed",
          duration_ms: 187_000,
          original_job_id: "f9630a48-5db7-4129-a4ea-8237ab6d9f51",
          executed_in_attempt: 2
        },
        %{
          id: "5fc28346-d7eb-4059-81a2-63b4f9d5ea8c",
          name: "Integration tests 2/2",
          result: "passed",
          duration_ms: 203_000,
          original_job_id: nil,
          executed_in_attempt: 4
        }
      ]
    }
  end

  defp e2e_block do
    %{
      name: "E2E tests",
      result: "passed",
      reused_from: nil,
      deps: ["Setup"],
      jobs: [
        %{
          id: "60d39457-e8fc-4160-92b3-74a50ae6fb9d",
          name: "Browser smoke suite",
          result: "passed",
          duration_ms: 246_000,
          original_job_id: nil,
          executed_in_attempt: 4
        },
        %{
          id: "71e4a568-f90d-4271-a3c4-8516b1f70cae",
          name: "Browser regression suite",
          result: "passed",
          duration_ms: 291_000,
          original_job_id: nil,
          executed_in_attempt: 4
        }
      ]
    }
  end

  defp packaging_block do
    %{
      name: "Packaging",
      result: "passed",
      reused_from: nil,
      deps: ["Unit tests", "Integration tests", "E2E tests"],
      jobs: [
        %{
          id: "82f5b679-0a1e-4382-b4d5-9627c2081dbf",
          name: "Build container image",
          result: "passed",
          duration_ms: 118_000,
          original_job_id: nil,
          executed_in_attempt: 4
        }
      ]
    }
  end
end
