defmodule GithubNotifier.Utils.LevelTest do
  use ExUnit.Case

  alias GithubNotifier.Utils.Level, as: L
  alias GithubNotifier.Models.Project

  alias InternalApi.Projecthub.Project.Spec.Repository.Status.PipelineFile.Level

  describe ".level" do
    test "when the status is nil => returns nil" do
      project = %Project{status: nil}
      pipeline = %GithubNotifier.Models.Pipeline{created_at: 1_561_939_199}

      assert L.level(project, pipeline) == []
    end

    test "when pipeline has no status set => returns nil" do
      project = %Project{status: %{"pipeline_files" => []}}
      pipeline = %GithubNotifier.Models.Pipeline{yaml_file_path: "bar"}

      assert L.level(project, pipeline) == []
    end

    test "when pipeline has status set to block => returns block" do
      project = %Project{
        status: %{
          "pipeline_files" => [
            %{"level" => Level.value(:BLOCK), "path" => "bar"}
          ]
        }
      }

      pipeline = %GithubNotifier.Models.Pipeline{yaml_file_path: "bar"}

      assert L.level(project, pipeline) == ["block"]
    end

    test "when pipeline has status set to block => returns pipeline" do
      project = %Project{
        status: %{
          "pipeline_files" => [
            %{"level" => Level.value(:PIPELINE), "path" => "bar"},
            %{"level" => Level.value(:PIPELINE), "path" => "foo"}
          ]
        }
      }

      pipeline = %GithubNotifier.Models.Pipeline{yaml_file_path: "bar"}

      assert L.level(project, pipeline) == ["pipeline"]
    end

    test "when pipeline has status set to block and pipeline => returns both" do
      project = %Project{
        status: %{
          "pipeline_files" => [
            %{"level" => Level.value(:PIPELINE), "path" => "bar"},
            %{"level" => Level.value(:BLOCK), "path" => "bar"}
          ]
        }
      }

      pipeline = %GithubNotifier.Models.Pipeline{yaml_file_path: "bar"}

      assert L.level(project, pipeline) == ["block", "pipeline"]
    end
  end
end
