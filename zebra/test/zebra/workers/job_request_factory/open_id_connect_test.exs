defmodule Zebra.Workers.JobRequestFactory.OpenIDConnectTest do
  use ExUnit.Case, async: true

  alias Zebra.Workers.JobRequestFactory.OpenIDConnect

  describe "construct_triggerer/1" do
    test "constructs triggerer with API workflow trigger" do
      env_vars = [
        %{"name" => "SEMAPHORE_WORKFLOW_TRIGGERED_BY_API", "value" => Base.encode64("true")},
        %{"name" => "SEMAPHORE_WORKFLOW_RERUN", "value" => Base.encode64("false")},
        %{"name" => "SEMAPHORE_PIPELINE_PROMOTED_BY", "value" => Base.encode64("")},
        %{"name" => "SEMAPHORE_PIPELINE_PROMOTION", "value" => Base.encode64("false")},
        %{"name" => "SEMAPHORE_PIPELINE_RERUN", "value" => Base.encode64("false")}
      ]

      result = OpenIDConnect.construct_triggerer("", "", "", env_vars, :pipeline_job)
      assert result == "a:f-i:f"
    end

    test "constructs triggerer with SCHEDULE workflow trigger" do
      env_vars = [
        %{"name" => "SEMAPHORE_WORKFLOW_TRIGGERED_BY_SCHEDULE", "value" => Base.encode64("true")},
        %{"name" => "SEMAPHORE_WORKFLOW_RERUN", "value" => Base.encode64("true")},
        %{"name" => "SEMAPHORE_PIPELINE_PROMOTED_BY", "value" => Base.encode64("gh-user")},
        %{"name" => "SEMAPHORE_PIPELINE_PROMOTION", "value" => Base.encode64("true")},
        %{"name" => "SEMAPHORE_PIPELINE_RERUN", "value" => Base.encode64("true")}
      ]

      result = OpenIDConnect.construct_triggerer("", "", "", env_vars, :pipeline_job)

      assert result ==
               "s:t-n:t"
    end

    test "constructs triggerer with MANUAL_RUN workflow trigger" do
      env_vars = [
        %{
          "name" => "SEMAPHORE_WORKFLOW_TRIGGERED_BY_MANUAL_RUN",
          "value" => Base.encode64("true")
        },
        %{"name" => "SEMAPHORE_WORKFLOW_RERUN", "value" => Base.encode64("false")},
        %{"name" => "SEMAPHORE_PIPELINE_PROMOTED_BY", "value" => Base.encode64("user")},
        %{"name" => "SEMAPHORE_PIPELINE_PROMOTION", "value" => Base.encode64("false")},
        %{"name" => "SEMAPHORE_PIPELINE_RERUN", "value" => Base.encode64("false")}
      ]

      result = OpenIDConnect.construct_triggerer("", "", "", env_vars, :pipeline_job)
      assert result == "m:f-i:f"
    end

    test "constructs triggerer with HOOK workflow trigger" do
      env_vars = [
        %{"name" => "SEMAPHORE_WORKFLOW_TRIGGERED_BY_HOOK", "value" => Base.encode64("true")},
        %{"name" => "SEMAPHORE_WORKFLOW_RERUN", "value" => Base.encode64("true")},
        %{"name" => "SEMAPHORE_PIPELINE_PROMOTED_BY", "value" => Base.encode64("auto-promotion")},
        %{"name" => "SEMAPHORE_PIPELINE_PROMOTION", "value" => Base.encode64("true")},
        %{"name" => "SEMAPHORE_PIPELINE_RERUN", "value" => Base.encode64("true")}
      ]

      result = OpenIDConnect.construct_triggerer("", "", "", env_vars, :pipeline_job)
      assert result == "h:t-u:t"
    end

    test "constructs triggerer with manual promotion" do
      env_vars = [
        %{"name" => "SEMAPHORE_WORKFLOW_TRIGGERED_BY_API", "value" => Base.encode64("false")},
        %{
          "name" => "SEMAPHORE_WORKFLOW_TRIGGERED_BY_MANUAL_RUN",
          "value" => Base.encode64("true")
        },
        %{"name" => "SEMAPHORE_PIPELINE_PROMOTED_BY", "value" => Base.encode64("user")},
        %{"name" => "SEMAPHORE_PIPELINE_PROMOTION", "value" => Base.encode64("true")},
        %{"name" => "SEMAPHORE_PIPELINE_RERUN", "value" => Base.encode64("false")}
      ]

      result = OpenIDConnect.construct_triggerer("", "", "", env_vars, :pipeline_job)

      assert result ==
               "m:f-n:f"
    end

    test "constructs triggerer with manual promotion for debug job" do
      env_vars = [
        %{"name" => "SEMAPHORE_WORKFLOW_TRIGGERED_BY_API", "value" => Base.encode64("false")},
        %{
          "name" => "SEMAPHORE_WORKFLOW_TRIGGERED_BY_MANUAL_RUN",
          "value" => Base.encode64("true")
        },
        %{"name" => "SEMAPHORE_PIPELINE_PROMOTED_BY", "value" => Base.encode64("user")},
        %{"name" => "SEMAPHORE_PIPELINE_PROMOTION", "value" => Base.encode64("true")},
        %{"name" => "SEMAPHORE_PIPELINE_RERUN", "value" => Base.encode64("false")}
      ]

      result = OpenIDConnect.construct_triggerer("", "", "", env_vars, :debug_job)

      assert result ==
               "m:f-n:f"
    end

    test "returns empty string for project debug job" do
      assert "" == OpenIDConnect.construct_triggerer("", "", "", [], :project_debug_job)
    end

    test "returns empty string for debug job with no triggerer environment variables" do
      assert "" ==
               OpenIDConnect.construct_triggerer("wf-123", "ppl-456", "job-789", [], :debug_job)
    end
  end
end
