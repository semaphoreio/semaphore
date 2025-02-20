defmodule Projecthub.Models.PeriodicTask.YamlTest do
  use ExUnit.Case, async: true

  alias Projecthub.Models.PeriodicTask
  alias Projecthub.Models.Project

  describe "compose/2" do
    test "paused" do
      expected = """
      apiVersion: v1.1
      kind: Schedule
      metadata:
        name: \"name\"
        id: \"id\"
        description: "test description"
      spec:
        project: \"project_name\"
        recurring: true
        paused: true
        at: \"* * * * *\"
        branch: \"master\"
        pipeline_file: \"semaphore.yml\"
      """

      assert ^expected =
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
    end

    test "without description" do
      expected = """
      apiVersion: v1.1
      kind: Schedule
      metadata:
        name: \"name\"
        id: \"id\"
        description: \"\"
      spec:
        project: \"project_name\"
        recurring: true
        paused: true
        at: \"* * * * *\"
        branch: \"master\"
        pipeline_file: \"semaphore.yml\"
      """

      assert ^expected =
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
    end

    test "without parameters" do
      expected = """
      apiVersion: v1.1
      kind: Schedule
      metadata:
        name: \"name\"
        id: \"id\"
        description: "test description"
      spec:
        project: \"project_name\"
        recurring: true
        paused: false
        at: \"* * * * *\"
        branch: \"master\"
        pipeline_file: \"semaphore.yml\"
      """

      assert ^expected =
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
    end

    test "without cron expression" do
      expected = """
      apiVersion: v1.1
      kind: Schedule
      metadata:
        name: \"name\"
        id: \"id\"
        description: "test description"
      spec:
        project: \"project_name\"
        recurring: false
        paused: false
        at: \"\"
        branch: \"master\"
        pipeline_file: \"semaphore.yml\"
      """

      assert ^expected =
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
    end

    test "with branch, pipeline file and parameters" do
      expected = """
      apiVersion: v1.1
      kind: Schedule
      metadata:
        name: \"name\"
        id: \"id\"
        description: "test description"
      spec:
        project: \"project_name\"
        recurring: true
        paused: false
        at: \"* * * * *\"
        branch: \"master\"
        pipeline_file: \"semaphore.yml\"
        parameters:
        - name: \"parameter1\"
          required: false
        - name: \"parameter2\"
          required: false
          default_value: \"option1\"
          description: \"description\"
          options:
          - \"option1\"
          - \"option2\"
      """

      assert ^expected =
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
    end
  end
end
