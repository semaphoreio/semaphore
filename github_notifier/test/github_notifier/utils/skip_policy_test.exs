defmodule GithubNotifier.Utils.SkipPolicyTest do
  use ExUnit.Case

  alias GithubNotifier.Models.{Pipeline, Project}
  alias GithubNotifier.Utils.SkipPolicy

  defp project(status \\ %{}) do
    %Project{status: Map.merge(%{"pipeline_files" => []}, status)}
  end

  defp pipeline(opts) do
    %Pipeline{
      triggered_by: Keyword.get(opts, :triggered_by, :HOOK),
      ppl_triggered_by: Keyword.get(opts, :ppl_triggered_by, :WORKFLOW),
      workflow_rerun_of: Keyword.get(opts, :workflow_rerun_of, "")
    }
  end

  describe ".skip?" do
    test "hook triggered pipelines post regardless of settings" do
      refute SkipPolicy.skip?(project(), pipeline(triggered_by: :HOOK))

      refute SkipPolicy.skip?(
               project(%{"skip_scheduled_run" => true, "skip_manual_run" => true}),
               pipeline(triggered_by: :HOOK)
             )
    end

    test "api triggered pipelines post regardless of settings" do
      refute SkipPolicy.skip?(project(), pipeline(triggered_by: :API))

      refute SkipPolicy.skip?(
               project(%{"skip_scheduled_run" => true, "skip_manual_run" => true}),
               pipeline(triggered_by: :API)
             )
    end

    test "scheduled pipelines post by default" do
      refute SkipPolicy.skip?(project(), pipeline(triggered_by: :SCHEDULE))

      refute SkipPolicy.skip?(
               project(%{"skip_scheduled_run" => false}),
               pipeline(triggered_by: :SCHEDULE)
             )
    end

    test "scheduled pipelines skip when the project sets skip_scheduled_run" do
      assert SkipPolicy.skip?(
               project(%{"skip_scheduled_run" => true}),
               pipeline(triggered_by: :SCHEDULE)
             )
    end

    test "manually run pipelines post by default" do
      refute SkipPolicy.skip?(project(), pipeline(triggered_by: :MANUAL_RUN))

      refute SkipPolicy.skip?(
               project(%{"skip_manual_run" => false}),
               pipeline(triggered_by: :MANUAL_RUN)
             )
    end

    test "manually run pipelines skip when the project sets skip_manual_run" do
      assert SkipPolicy.skip?(
               project(%{"skip_manual_run" => true}),
               pipeline(triggered_by: :MANUAL_RUN)
             )
    end

    test "workflow reruns always post" do
      refute SkipPolicy.skip?(
               project(%{"skip_scheduled_run" => true}),
               pipeline(triggered_by: :SCHEDULE, workflow_rerun_of: "some-wf-id")
             )
    end

    test "partial reruns always post" do
      refute SkipPolicy.skip?(
               project(%{"skip_manual_run" => true}),
               pipeline(triggered_by: :MANUAL_RUN, ppl_triggered_by: :PARTIAL_RE_RUN)
             )
    end

    test "pipelines post when the project has no status config" do
      refute SkipPolicy.skip?(%Project{status: nil}, pipeline(triggered_by: :SCHEDULE))
      refute SkipPolicy.skip?(%Project{status: nil}, pipeline(triggered_by: :MANUAL_RUN))
    end

    test "legacy status maps without the new keys post everything" do
      legacy = %Project{status: %{"pipeline_files" => [%{"path" => "p", "level" => "pipeline"}]}}

      refute SkipPolicy.skip?(legacy, pipeline(triggered_by: :HOOK))
      refute SkipPolicy.skip?(legacy, pipeline(triggered_by: :MANUAL_RUN))
      refute SkipPolicy.skip?(legacy, pipeline(triggered_by: :SCHEDULE))
    end
  end

  describe ".skip? with a task policy" do
    alias GithubNotifier.Models.Periodic

    defp task(commit_status), do: %Periodic{id: "task-1", commit_status: commit_status}

    test "task ALWAYS posts even when the project skips" do
      for trigger <- [:SCHEDULE, :MANUAL_RUN] do
        refute SkipPolicy.skip?(
                 project(%{"skip_scheduled_run" => true, "skip_manual_run" => true}),
                 pipeline(triggered_by: trigger),
                 task(:ALWAYS)
               )
      end
    end

    test "task NEVER skips even when the project posts" do
      for trigger <- [:SCHEDULE, :MANUAL_RUN] do
        assert SkipPolicy.skip?(project(), pipeline(triggered_by: trigger), task(:NEVER))
      end
    end

    test "task FOLLOW_PROJECT falls back to the project settings" do
      assert SkipPolicy.skip?(
               project(%{"skip_scheduled_run" => true}),
               pipeline(triggered_by: :SCHEDULE),
               task(:FOLLOW_PROJECT)
             )

      refute SkipPolicy.skip?(project(), pipeline(triggered_by: :SCHEDULE), task(:FOLLOW_PROJECT))
    end

    test "an unresolvable task falls back to the project settings" do
      assert SkipPolicy.skip?(
               project(%{"skip_manual_run" => true}),
               pipeline(triggered_by: :MANUAL_RUN),
               nil
             )

      refute SkipPolicy.skip?(project(), pipeline(triggered_by: :MANUAL_RUN), nil)
    end

    test "task policy does not affect hook or api triggers" do
      for trigger <- [:HOOK, :API] do
        refute SkipPolicy.skip?(project(), pipeline(triggered_by: trigger), task(:NEVER))
      end
    end

    test "reruns post even when the task says NEVER" do
      refute SkipPolicy.skip?(
               project(),
               pipeline(triggered_by: :SCHEDULE, workflow_rerun_of: "prev-wf"),
               task(:NEVER)
             )

      refute SkipPolicy.skip?(
               project(),
               pipeline(triggered_by: :MANUAL_RUN, ppl_triggered_by: :PARTIAL_RE_RUN),
               task(:NEVER)
             )
    end
  end
end
