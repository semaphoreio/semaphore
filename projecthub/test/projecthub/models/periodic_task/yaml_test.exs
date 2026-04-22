defmodule Projecthub.Models.PeriodicTask.YamlTest do
  use ExUnit.Case, async: true

  alias Projecthub.Models.PeriodicTask
  alias Projecthub.Models.Project

  # Helper to parse YAML and compare data structures
  defp assert_yaml_equals(actual_yaml, expected_map) do
    {:ok, actual_map} = YamlElixir.read_from_string(actual_yaml)
    assert actual_map == expected_map
  end

  describe "compose/2" do
    test "paused" do
      result =
        Projecthub.Models.PeriodicTask.YAML.compose(
          %PeriodicTask{
            id: "id",
            name: "name",
            description: "test description",
            project_name: "project_name",
            status: :STATUS_INACTIVE,
            recurring: true,
            branch: "master",
            at: "* * * * *",
            pipeline_file: "semaphore.yml"
          },
          %Project{name: "project_name"}
        )

      assert_yaml_equals(
        result,
        %{
          "apiVersion" => "v1.2",
          "kind" => "Schedule",
          "metadata" => %{
            "name" => "name",
            "id" => "id",
            "description" => "test description"
          },
          "spec" => %{
            "project" => "project_name",
            "recurring" => true,
            "paused" => true,
            "at" => "* * * * *",
            "reference" => %{"type" => "BRANCH", "name" => "master"},
            "pipeline_file" => "semaphore.yml"
          }
        }
      )
    end

    test "without description" do
      result =
        Projecthub.Models.PeriodicTask.YAML.compose(
          %PeriodicTask{
            id: "id",
            name: "name",
            description: "",
            project_name: "project_name",
            status: :STATUS_INACTIVE,
            recurring: true,
            branch: "master",
            at: "* * * * *",
            pipeline_file: "semaphore.yml"
          },
          %Project{name: "project_name"}
        )

      assert_yaml_equals(
        result,
        %{
          "apiVersion" => "v1.2",
          "kind" => "Schedule",
          "metadata" => %{
            "name" => "name",
            "id" => "id",
            "description" => ""
          },
          "spec" => %{
            "project" => "project_name",
            "recurring" => true,
            "paused" => true,
            "at" => "* * * * *",
            "reference" => %{"type" => "BRANCH", "name" => "master"},
            "pipeline_file" => "semaphore.yml"
          }
        }
      )
    end

    test "without parameters" do
      result =
        Projecthub.Models.PeriodicTask.YAML.compose(
          %PeriodicTask{
            id: "id",
            name: "name",
            description: "test description",
            project_name: "project_name",
            recurring: true,
            branch: "master",
            at: "* * * * *",
            pipeline_file: "semaphore.yml"
          },
          %Project{name: "project_name"}
        )

      assert_yaml_equals(result, %{
        "apiVersion" => "v1.2",
        "kind" => "Schedule",
        "metadata" => %{
          "name" => "name",
          "id" => "id",
          "description" => "test description"
        },
        "spec" => %{
          "project" => "project_name",
          "recurring" => true,
          "paused" => false,
          "at" => "* * * * *",
          "reference" => %{"type" => "BRANCH", "name" => "master"},
          "pipeline_file" => "semaphore.yml"
        }
      })
    end

    test "without cron expression" do
      result =
        Projecthub.Models.PeriodicTask.YAML.compose(
          %PeriodicTask{
            id: "id",
            name: "name",
            description: "test description",
            project_name: "project_name",
            recurring: false,
            branch: "master",
            pipeline_file: "semaphore.yml"
          },
          %Project{name: "project_name"}
        )

      assert_yaml_equals(result, %{
        "apiVersion" => "v1.2",
        "kind" => "Schedule",
        "metadata" => %{
          "name" => "name",
          "id" => "id",
          "description" => "test description"
        },
        "spec" => %{
          "project" => "project_name",
          "recurring" => false,
          "paused" => false,
          "at" => "",
          "reference" => %{"type" => "BRANCH", "name" => "master"},
          "pipeline_file" => "semaphore.yml"
        }
      })
    end

    test "with reference, pipeline file and parameters" do
      result =
        Projecthub.Models.PeriodicTask.YAML.compose(
          %PeriodicTask{
            id: "id",
            name: "name",
            description: "test description",
            project_name: "project_name",
            recurring: true,
            branch: "master",
            pipeline_file: "semaphore.yml",
            at: "* * * * *",
            parameters: [
              %{
                name: "parameter1",
                required: false
              },
              %{
                name: "parameter2",
                required: false,
                description: "description",
                default_value: "option1",
                options: ["option1", "option2"]
              }
            ]
          },
          %Project{name: "project_name"}
        )

      assert_yaml_equals(result, %{
        "apiVersion" => "v1.2",
        "kind" => "Schedule",
        "metadata" => %{
          "name" => "name",
          "id" => "id",
          "description" => "test description"
        },
        "spec" => %{
          "project" => "project_name",
          "recurring" => true,
          "paused" => false,
          "at" => "* * * * *",
          "reference" => %{"type" => "BRANCH", "name" => "master"},
          "pipeline_file" => "semaphore.yml",
          "parameters" => [
            %{"name" => "parameter1", "required" => false},
            %{
              "name" => "parameter2",
              "required" => false,
              "description" => "description",
              "default_value" => "option1",
              "options" => ["option1", "option2"]
            }
          ]
        }
      })
    end

    test "with tag reference" do
      result =
        Projecthub.Models.PeriodicTask.YAML.compose(
          %PeriodicTask{
            id: "tag-id",
            name: "release-task",
            description: "tag release task",
            project_name: "project_name",
            recurring: false,
            branch: "refs/tags/v1.0.0",
            pipeline_file: "semaphore.yml"
          },
          %Project{name: "project_name"}
        )

      assert_yaml_equals(result, %{
        "apiVersion" => "v1.2",
        "kind" => "Schedule",
        "metadata" => %{
          "name" => "release-task",
          "id" => "tag-id",
          "description" => "tag release task"
        },
        "spec" => %{
          "project" => "project_name",
          "recurring" => false,
          "paused" => false,
          "at" => "",
          "reference" => %{"type" => "TAG", "name" => "v1.0.0"},
          "pipeline_file" => "semaphore.yml"
        }
      })
    end

    test "with pull request reference" do
      result =
        Projecthub.Models.PeriodicTask.YAML.compose(
          %PeriodicTask{
            id: "pr-id",
            name: "pr-task",
            description: "PR task",
            project_name: "project_name",
            recurring: false,
            branch: "refs/pull/123/head",
            pipeline_file: "semaphore.yml"
          },
          %Project{name: "project_name"}
        )

      assert_yaml_equals(result, %{
        "apiVersion" => "v1.2",
        "kind" => "Schedule",
        "metadata" => %{
          "name" => "pr-task",
          "id" => "pr-id",
          "description" => "PR task"
        },
        "spec" => %{
          "project" => "project_name",
          "recurring" => false,
          "paused" => false,
          "at" => "",
          "reference" => %{"type" => "PR", "name" => "123"},
          "pipeline_file" => "semaphore.yml"
        }
      })
    end

    test "escapes double quotes in description and parameter values" do
      # This test ensures that JSON-like content with double quotes is properly escaped
      # to prevent "malformed yaml" errors from the Semaphore API
      result =
        Projecthub.Models.PeriodicTask.YAML.compose(
          %PeriodicTask{
            id: "id",
            name: "task-with-quotes",
            description: "Example: '{\"kafka\": \"value\"}' is valid JSON",
            project_name: "project_name",
            recurring: false,
            branch: "master",
            pipeline_file: "semaphore.yml",
            parameters: [
              %{
                name: "ENTITY_MAPPING",
                required: true,
                description: "Dictionary of mappings. Example: '{\"key\": \"value\"}'",
                default_value: "{\"kafka1\": {\"lkc\": \"lkc-123\"}}",
                options: ["{\"opt1\": \"val1\"}", "{\"opt2\": \"val2\"}"]
              }
            ]
          },
          %Project{name: "project_name"}
        )

      # Verify the YAML is valid and can be parsed
      assert {:ok, parsed} = YamlElixir.read_from_string(result)

      # Verify the values are preserved correctly after round-trip
      assert parsed["metadata"]["description"] == "Example: '{\"kafka\": \"value\"}' is valid JSON"

      assert hd(parsed["spec"]["parameters"])["description"] ==
               "Dictionary of mappings. Example: '{\"key\": \"value\"}'"

      assert hd(parsed["spec"]["parameters"])["default_value"] ==
               "{\"kafka1\": {\"lkc\": \"lkc-123\"}}"

      assert hd(parsed["spec"]["parameters"])["options"] ==
               ["{\"opt1\": \"val1\"}", "{\"opt2\": \"val2\"}"]
    end

    test "escapes backslashes in values" do
      # Ensure backslashes are also escaped to prevent YAML parsing issues
      result =
        Projecthub.Models.PeriodicTask.YAML.compose(
          %PeriodicTask{
            id: "id",
            name: "task",
            description: "Path: C:\\Users\\test",
            project_name: "project_name",
            recurring: false,
            branch: "master",
            pipeline_file: "semaphore.yml"
          },
          %Project{name: "project_name"}
        )

      # Verify the YAML is valid and can be parsed
      assert {:ok, parsed} = YamlElixir.read_from_string(result)

      # Verify the backslashes are preserved correctly
      assert parsed["metadata"]["description"] == "Path: C:\\Users\\test"
    end
  end
end
