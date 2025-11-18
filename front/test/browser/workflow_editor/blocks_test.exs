# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Front.Browser.WorkflowEditor.BlocksTest do
  use FrontWeb.WallabyCase

  alias Support.Browser.WorkflowEditor, as: Editor

  alias Wallaby.Query

  setup %{session: session} do
    Editor.init()

    Support.Stubs.PermissionPatrol.allow_everything()

    workflow = Editor.get_workflow()

    page = Editor.open(session, workflow.id)

    {:ok, %{page: page}}
  end

  browser_test "users can add new blocks", %{page: page} do
    block_count =
      page
      |> all(Query.css("#workflow-editor-diagram [data-type=block]"))
      |> length

    page
    |> click(Query.data("action", "addBlock"))
    |> assert_text("Block ##{block_count + 1}")
  end

  browser_test "adding a secret to block", %{page: page} do
    secret = Support.Stubs.Secret.last()
    secret_name = secret.api_model.metadata.name

    page =
      page
      |> Editor.select_first_block()
      |> Editor.expand_config("Secrets")
      |> Editor.in_config("Secrets", fn cfg ->
        cfg |> click(Query.css("label", text: secret_name))
      end)

    secret =
      page
      |> Editor.get_first_pipeline()
      |> get_in(["blocks", Access.at(0), "task", "secrets", Access.at(0)])

    assert secret["name"] == secret_name
  end

  browser_test "editing prologue commands", %{page: page} do
    text = "    \necho C\n      "

    page =
      page
      |> Editor.select_first_block()
      |> Editor.expand_config("Prologue")
      |> Editor.in_config("Prologue", fn cfg ->
        cfg |> fill_in(Query.css("textarea"), with: text)
      end)
      |> Editor.select_first_block()

    :timer.sleep(600)

    commands =
      page
      |> Editor.first_block_yaml()
      |> get_in(["task", "prologue", "commands"])

    assert commands == ["echo C"]
  end

  browser_test "editing epilogue always commands", %{page: page} do
    always_text = "echo always"

    page =
      page
      |> Editor.select_first_block()
      |> Editor.expand_config("Epilogue")
      |> Editor.in_config("Epilogue", fn cfg ->
        cfg |> fill_in(Query.text_field("Execute always"), with: always_text)
      end)
      |> Editor.select_first_block()

    :timer.sleep(600)

    block = Editor.first_block_yaml(page)

    always = block |> get_in(["task", "epilogue", "always", "commands"])

    assert always == ["echo always"]
  end

  browser_test "editing epilogue on-fail commands", %{page: page} do
    on_fail_text = "    \necho fail\n      "

    page =
      page
      |> Editor.select_first_block()
      |> Editor.expand_config("Epilogue")
      |> Editor.in_config("Epilogue", fn cfg ->
        cfg |> fill_in(Query.text_field("If job has failed"), with: on_fail_text)
      end)
      |> Editor.select_first_block()

    :timer.sleep(600)

    block = Editor.first_block_yaml(page)

    on_fail = block |> get_in(["task", "epilogue", "on_fail", "commands"])

    assert on_fail == ["echo fail"]
  end

  browser_test "editing epilogue on-pass commands", %{page: page} do
    on_pass_text = "echo pass1\n     \necho pass2"

    page =
      page
      |> Editor.select_first_block()
      |> Editor.expand_config("Epilogue")
      |> Editor.in_config("Epilogue", fn cfg ->
        cfg |> fill_in(Query.text_field("If job has passed"), with: on_pass_text)
      end)
      |> Editor.select_first_block()

    :timer.sleep(600)

    block = Editor.first_block_yaml(page)
    on_pass = block |> get_in(["task", "epilogue", "on_pass", "commands"])

    assert on_pass == ["echo pass1", "echo pass2"]
  end

  describe "jobs" do
    setup %{page: page} do
      page = page |> Editor.select_first_block()

      {:ok, %{page: page}}
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

      block = Editor.first_block_yaml(page)
      job = block |> get_in(["task", "jobs", Access.at(0)])

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

      block = Editor.first_block_yaml(page)
      job = block |> get_in(["task", "jobs", Access.at(0)])

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
  end

  describe "agents" do
    setup %{page: page} do
      page =
        page
        |> execute_script("window.confirm = function(){return true;}")
        |> Editor.select_first_block()
        |> Editor.expand_config("Agent")

      {:ok, %{page: page}}
    end

    browser_test "enabling global override", %{page: page} do
      # enable
      page = page |> click(Query.checkbox("Override global agent definition"))

      yaml = Editor.first_block_yaml(page)
      assert get_in(yaml, ["task", "agent"]) != nil

      # disable
      page = page |> click(Query.checkbox("Override global agent definition"))

      yaml = Editor.first_block_yaml(page)
      assert get_in(yaml, ["task", "agent"]) == nil
    end

    browser_test "configuring Linux VM agent", %{page: page} do
      # enable
      page = page |> click(Query.checkbox("Override global agent definition"))
      page = page |> Editor.change_agent_env_type_for_block("Linux Based Virtual Machine")

      page =
        page
        |> Editor.in_config("Agent", fn cfg ->
          cfg |> Editor.scroll_config_to_bottom()

          cfg |> click(Query.radio_button("e1-standard-4"))
        end)

      yaml = Editor.first_block_yaml(page)
      assert get_in(yaml, ["task", "agent", "containers"]) == nil
      assert get_in(yaml, ["task", "agent", "machine", "type"]) == "e1-standard-4"
    end

    browser_test "configuring Mac VM agent", %{page: page} do
      # enable
      page = page |> click(Query.checkbox("Override global agent definition"))
      page = page |> Editor.change_agent_env_type_for_block("Mac Based Virtual Machine")

      yaml = Editor.first_block_yaml(page)
      assert get_in(yaml, ["task", "agent", "containers"]) == nil
      assert get_in(yaml, ["task", "agent", "machine", "type"]) == "a1-standard-4"
    end

    browser_test "configuring Docker based VM agent", %{page: page} do
      # enable
      page = page |> click(Query.checkbox("Override global agent definition"))

      # first, make sure we are not in docker
      page = page |> Editor.change_agent_env_type_for_block("Linux Based Virtual Machine")

      # then, switch to docker
      page = page |> Editor.change_agent_env_type_for_block("Docker Container(s)")

      yaml = Editor.first_block_yaml(page)
      assert get_in(yaml, ["task", "agent", "machine", "type"]) == "e1-standard-2"

      assert get_in(yaml, ["task", "agent", "containers"]) == [
               %{
                 "name" => "main",
                 "image" => "semaphoreci/ubuntu:20.04"
               }
             ]

      page =
        page
        |> Editor.in_config("Agent", fn cfg ->
          cfg
          |> find(Query.text_field("container-image-0"), fn el ->
            Wallaby.Element.clear(el)
          end)
        end)
        |> Editor.in_config("Agent", fn cfg ->
          cfg
          |> find(Query.text_field("container-image-0"), fn el ->
            Wallaby.Element.set_value(el, "semaphoreci/ruby:2.6")
          end)
        end)

      page =
        page
        |> Editor.in_config("Agent", fn cfg ->
          cfg |> click(Query.radio_button("e1-standard-8"))
        end)

      :timer.sleep(500)

      yaml = Editor.first_block_yaml(page)
      assert get_in(yaml, ["task", "agent", "machine", "type"]) == "e1-standard-8"

      assert get_in(yaml, ["task", "agent", "containers"]) == [
               %{
                 "name" => "main",
                 "image" => "semaphoreci/ruby:2.6"
               }
             ]
    end

    browser_test "self-hosted environment is not available if no agent types are created", %{
      page: page
    } do
      page
      |> click(Query.checkbox("Override global agent definition"))
      |> Editor.in_config("Agent", fn cfg ->
        cfg
        |> find(Query.select("Environment Type"), fn select ->
          select |> refute_has(Query.option("Self-Hosted Machine"))
        end)
      end)
    end
  end

  describe "skip/run conditions" do
    setup %{page: page} do
      page =
        page
        |> execute_script("window.confirm = function(){return true;}")
        |> Editor.select_first_block()
        |> Editor.expand_config("Skip/Run conditions")

      {:ok, %{page: page}}
    end

    browser_test "setting up a skip condition", %{page: page} do
      page =
        page
        |> change_skip_condition_type("Skip this block when conditions are met")
        |> Editor.fill(Query.text_field("Skip when?"), "branch = 'dev'")

      :timer.sleep(500)

      assert page |> Editor.first_block_yaml() |> get_in(["skip", "when"]) == "branch = 'dev'"
    end

    browser_test "setting up a run condition", %{page: page} do
      page =
        page
        |> change_skip_condition_type("Run this block when conditions are met")
        |> Editor.fill(Query.text_field("Run when?"), "branch = 'dev'")

      :timer.sleep(500)

      assert page |> Editor.first_block_yaml() |> get_in(["run", "when"]) == "branch = 'dev'"
    end
  end

  def change_skip_condition_type(page, type) do
    page
    |> Editor.in_config("Skip/Run conditions", fn cfg ->
      cfg
      |> find(Query.css("select"), fn select ->
        select |> click(Query.option(type))
      end)
    end)
  end
end
