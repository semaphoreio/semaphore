defmodule Front.WorkflowPage.DiagramTest do
  use FrontWeb.ConnCase

  alias Front.WorkflowPage.Diagram
  alias Support.Stubs

  setup do
    user = Stubs.User.create_default()
    org = Stubs.Organization.create_default()
    project = Stubs.Project.create(org, user)
    branch = Stubs.Branch.create(project)

    hook = Stubs.Hook.create(branch)
    workflow = Stubs.Workflow.create(hook, user)

    pipeline =
      Stubs.Pipeline.create_initial(workflow, name: "Build & Test", organization_id: org.id)

    blocks =
      Stubs.Pipeline.add_blocks(pipeline, [
        %{name: "Block 1"},
        %{name: "Block 2", dependencies: ["Block 1"]},
        %{name: "Block 3", dependencies: ["Block 1"]}
      ])

    {:ok, %{pipeline: pipeline, blocks: blocks}}
  end

  describe ".load" do
    test "it loads blocks", context do
      pipeline = Front.Models.Pipeline.find(context.pipeline.id)
      diagram = Diagram.load(pipeline)

      assert length(diagram.blocks) == 3

      assert Enum.at(diagram.blocks, 0).name == "Block 1"
      assert Enum.at(diagram.blocks, 1).name == "Block 2"
      assert Enum.at(diagram.blocks, 2).name == "Block 3"
    end

    test "it populates job names", context do
      pipeline = Front.Models.Pipeline.find(context.pipeline.id)
      diagram = Diagram.load(pipeline)

      job = first_job(diagram.blocks)

      assert Map.keys(job) == [:name]
      assert exists?(job.name)
    end

    test "when the blocks have associated tasks, injects rich job info", context do
      create_tasks(context.blocks)

      pipeline = Front.Models.Pipeline.find(context.pipeline.id)
      diagram = Diagram.load(pipeline)

      job = first_job(diagram.blocks)

      assert exists?(job.id)
      assert exists?(job.name)
      assert exists?(job.index)
      assert exists?(job.state)

      assert Map.has_key?(job, :created_at)
      assert Map.has_key?(job, :finished_at)
    end

    test "when the pipeline has a compile task", context do
      Support.Stubs.Pipeline.add_compile_task(context.pipeline.id)

      pipeline = Front.Models.Pipeline.find(context.pipeline.id)
      diagram = Diagram.load(pipeline)

      assert diagram.compile_task.present?
      assert exists?(diagram.compile_task.task_id)
      assert exists?(diagram.compile_task.job_id)
      assert exists?(diagram.compile_task.job_log_path)
    end

    test "when the pipeline has a after task", context do
      Support.Stubs.Pipeline.add_after_task(context.pipeline.id)

      pipeline = Front.Models.Pipeline.find(context.pipeline.id)
      diagram = Diagram.load(pipeline)

      assert diagram.after_task.present? == true
      assert diagram.after_task.task_id != nil

      assert diagram.after_task.jobs == [
               %{
                 done?: false,
                 done_at: nil,
                 failed?: false,
                 id: nil,
                 name: "Clean",
                 passed?: false,
                 running?: false,
                 started_at: nil,
                 stopped?: false
               }
             ]
    end
  end

  describe "waiting for quota" do
    test "when the pipeline tasks are not waiting => inject no waiting info", context do
      pipeline = Front.Models.Pipeline.find(context.pipeline.id)
      diagram = Diagram.load(pipeline)

      refute diagram.jobs_are_waiting?
    end

    test "when the pipeline tasks are waiting => inject waiting info", context do
      Support.Stubs.Time.travel_back(:timer.minutes(2), fn ->
        create_tasks(context.blocks)
      end)

      pipeline = Front.Models.Pipeline.find(context.pipeline.id)
      diagram = Diagram.load(pipeline)

      assert diagram.jobs_are_waiting?
    end
  end

  defp create_tasks(blocks) do
    blocks |> Enum.each(fn b -> Support.Stubs.Task.create(b) end)
  end

  defp first_job(blocks) do
    hd(Enum.at(blocks, 0).jobs)
  end

  defp exists?(val) do
    val != nil && val != ""
  end
end
