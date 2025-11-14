# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Front.Browser.WorkflowEditor.AfterPipelineTest do
  use FrontWeb.WallabyCase

  alias Support.Browser.WorkflowEditor, as: Editor

  setup %{session: session} do
    Editor.init()

    Support.Stubs.PermissionPatrol.allow_everything()

    workflow = Editor.get_workflow()

    page = Editor.open(session, workflow.id)

    {:ok, %{page: page}}
  end

  browser_test "when configure is clicked the after pipeline config panel is shown", %{page: page} do
    page |> click(Query.data("action", "configureAfterPipeline"))

    assert_text(page, "Job #1")
  end

  describe "jobs" do
    setup %{page: page} do
      page |> click(Query.data("action", "configureAfterPipeline"))

      {:ok, %{page: page}}
    end

    browser_test "setting up a simple job", %{page: page} do
      after_pipeline = after_pipeline_yaml(page)

      job = after_pipeline |> get_in(["task", "jobs", Access.at(0)])

      assert job["name"] == "Job #1"
    end

    browser_test "setting up job parallelism", %{page: page} do
      page
      |> Editor.expand_config("Configure parallelism or a job matrix")
      |> select_parallelism_type("Multiple instances")
      |> Editor.in_config("Configure parallelism or a job matrix", fn cfg ->
        cfg
        |> execute_script("""
          let input = document.querySelector("input[type=range]");
          input.value = 8;
          input.dispatchEvent(new Event("input", { bubbles: true }));
        """)
      end)

      after_pipeline = after_pipeline_yaml(page)
      job = after_pipeline |> get_in(["task", "jobs", Access.at(0)])

      assert job["parallelism"] == 8
    end

    browser_test "setting up job matrix", %{page: page} do
      page =
        page
        |> Editor.expand_config("Configure parallelism or a job matrix")
        |> select_parallelism_type("Multiple instances based on a matrix")
        |> add_matrix_env()
        |> change_matrix_env(0, "RUBY_VER", "2.1, 2.2, 2.3")
        |> change_matrix_env(1, "NODE_VER", "11, 12")

      after_pipeline = after_pipeline_yaml(page)
      job = after_pipeline |> get_in(["task", "jobs", Access.at(0)])

      assert job["matrix"] == [
               %{"env_var" => "RUBY_VER", "values" => ["2.1", "2.2", "2.3"]},
               %{"env_var" => "NODE_VER", "values" => ["11", "12"]}
             ]
    end

    def change_matrix_env(page, index, name, values) do
      name_selector = "[data-action='changeMatrixEnvVarName'][data-env-index='#{index}']"
      values_selector = "[data-action='changeMatrixEnvVarValues'][data-env-index='#{index}']"

      page
      |> execute_script("""
        let name = document.querySelector("#{name_selector}");
        name.value = "#{name}";
        name.dispatchEvent(new Event("change", { bubbles: true }));

        let values = document.querySelector("#{values_selector}");
        values.value = "#{values}";
        values.dispatchEvent(new Event("change", { bubbles: true }));
      """)
    end

    def select_parallelism_type(page, type) do
      page
      |> Editor.in_config("Configure parallelism or a job matrix", fn cfg ->
        cfg
        |> find(Query.select("How many parallel instances to run?"), fn select ->
          select |> click(Query.option(type))
        end)
      end)
    end

    def add_matrix_env(page) do
      page
      |> Editor.in_config("Configure parallelism or a job matrix", fn cfg ->
        cfg |> click(Query.link("+ Add variable"))
      end)
    end

    def after_pipeline_yaml(page) do
      page
      |> Editor.get_first_pipeline()
      |> get_in(["after_pipeline"])
    end
  end
end
