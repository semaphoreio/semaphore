defmodule Front.Browser.WorkflowEditor.PipelineTest do
  use FrontWeb.WallabyCase

  alias Support.Browser.WorkflowEditor, as: Editor

  setup %{session: session} do
    Editor.init()

    Support.Stubs.PermissionPatrol.allow_everything()

    workflow = Editor.get_workflow()

    page = Editor.open(session, workflow.id)

    {:ok, %{page: page}}
  end

  describe "agents" do
    setup %{page: page} do
      page =
        page
        |> execute_script("window.confirm = function(){return true;}")
        |> Editor.select_first_pipeline()

      {:ok, %{page: page}}
    end

    browser_test "configuring Linux VM agent", %{page: page} do
      page = page |> Editor.change_agent_env_type_for_pipeline("Linux Based Virtual Machine")

      page =
        page
        |> click(Query.radio_button("e1-standard-4"))

      yaml = Editor.get_first_pipeline(page)
      assert get_in(yaml, ["agent", "containers"]) == nil
      assert get_in(yaml, ["agent", "machine", "type"]) == "e1-standard-4"
    end

    browser_test "configuring Mac VM agent", %{page: page} do
      page = page |> Editor.change_agent_env_type_for_pipeline("Mac Based Virtual Machine")

      yaml = Editor.get_first_pipeline(page)
      assert get_in(yaml, ["agent", "containers"]) == nil
      assert get_in(yaml, ["agent", "machine", "type"]) == "a1-standard-4"
    end

    browser_test "configuring Docker based VM agent", %{page: page} do
      # first, make sure we are not in docker
      page = page |> Editor.change_agent_env_type_for_pipeline("Linux Based Virtual Machine")

      # then, switch to docker
      page = page |> Editor.change_agent_env_type_for_pipeline("Docker Container(s)")

      yaml = Editor.get_first_pipeline(page)
      assert get_in(yaml, ["agent", "machine", "type"]) == "e1-standard-2"

      assert get_in(yaml, ["agent", "containers"]) == [
               %{
                 "name" => "main",
                 "image" => "semaphoreci/ubuntu:20.04"
               }
             ]

      page =
        page
        |> Editor.fill(Query.text_field("container-image-0"), "semaphoreci/ruby:2.6")
        |> click(Query.radio_button("e1-standard-8"))

      :timer.sleep(500)

      yaml = Editor.get_first_pipeline(page)
      assert get_in(yaml, ["agent", "machine", "type"]) == "e1-standard-8"

      assert get_in(yaml, ["agent", "containers"]) == [
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
      |> find(Query.select("Environment Type"), fn select ->
        select |> refute_has(Query.option("Self-Hosted Machine"))
      end)
    end
  end

  describe "fail-fast" do
    setup %{page: page} do
      page = page |> Editor.select_first_pipeline() |> Editor.expand_config("Fail-Fast")

      {:ok, %{page: page}}
    end

    browser_test "disable fail-fast", %{page: page} do
      # setting to non-disabled
      page = page |> change_fail_fast_type("Stop all remaining jobs")

      yaml = Editor.get_first_pipeline(page)
      assert get_in(yaml, ["fail_fast"]) == %{"stop" => %{"when" => "true"}}

      # testing if returning to disabled works
      page = page |> Editor.select_first_pipeline() |> change_fail_fast_type("Do nothing")
      yaml = Editor.get_first_pipeline(page)
      assert get_in(yaml, ["fail_fast"]) == nil
    end

    browser_test "setting strategy to stop all remaining jobs", %{page: page} do
      page = page |> change_fail_fast_type("Stop all remaining jobs")

      yaml = Editor.get_first_pipeline(page)
      assert get_in(yaml, ["fail_fast"]) == %{"stop" => %{"when" => "true"}}
    end

    browser_test "setting strategy to cancel all pending jobs", %{page: page} do
      page =
        page |> change_fail_fast_type("Cancel all pending jobs, wait for started ones to finish")

      yaml = Editor.get_first_pipeline(page)
      assert get_in(yaml, ["fail_fast"]) == %{"cancel" => %{"when" => "true"}}
    end

    browser_test "setting strategy to stop on non-master", %{page: page} do
      page =
        page
        |> change_fail_fast_type(
          "Stop remaining jobs, unless the job is running on the master branch"
        )

      yaml = Editor.get_first_pipeline(page)
      assert get_in(yaml, ["fail_fast"]) == %{"stop" => %{"when" => "branch != 'master'"}}
    end

    browser_test "setting strategy to a custom one", %{page: page} do
      page = page |> change_fail_fast_type("Run a custom fail-fast strategy")

      page =
        page
        |> Editor.fill(Query.text_field("Stop all jobs when:"), "branch != 'dev'")
        |> Editor.select_first_pipeline()
        |> Editor.fill(Query.text_field("Stop only pending jobs when:"), "branch != 'test'")
        |> Editor.select_first_pipeline()

      :timer.sleep(600)

      yaml = Editor.get_first_pipeline(page)

      assert get_in(yaml, ["fail_fast"]) == %{
               "stop" => %{"when" => "branch != 'dev'"},
               "cancel" => %{"when" => "branch != 'test'"}
             }
    end
  end

  describe "auto-cancel" do
    setup %{page: page} do
      page = page |> Editor.select_first_pipeline() |> Editor.expand_config("Auto-Cancel")

      {:ok, %{page: page}}
    end

    @strategy_do_nothing "Do nothing"
    @strategy_cancel_all "Cancel all pipelines, both running and queued"
    @strategy_queued "Cancel only queued pipelines"
    @strategy_master "On the master branch cancel only queued pipelines, on others cancel both running and queued"
    @strategy_custom "Run a custom auto-cancel strategy"

    browser_test "disable auto-cancel", %{page: page} do
      # setting to non-disabled
      page = page |> change_auto_cancel_type(@strategy_cancel_all)

      yaml = Editor.get_first_pipeline(page)
      assert get_in(yaml, ["auto_cancel"]) == %{"running" => %{"when" => "true"}}

      # testing if returning to disabled works
      page =
        page |> Editor.select_first_pipeline() |> change_auto_cancel_type(@strategy_do_nothing)

      yaml = Editor.get_first_pipeline(page)
      assert get_in(yaml, ["auto_cancel"]) == nil
    end

    browser_test "setting strategy to cancel all", %{page: page} do
      page = page |> change_auto_cancel_type(@strategy_cancel_all)

      yaml = Editor.get_first_pipeline(page)
      assert get_in(yaml, ["auto_cancel"]) == %{"running" => %{"when" => "true"}}
    end

    browser_test "setting strategy to cancel all queued pipelines", %{page: page} do
      page = page |> change_auto_cancel_type(@strategy_queued)

      yaml = Editor.get_first_pipeline(page)
      assert get_in(yaml, ["auto_cancel"]) == %{"queued" => %{"when" => "true"}}
    end

    browser_test "setting strategy to stop on non-master", %{page: page} do
      page = page |> change_auto_cancel_type(@strategy_master)

      yaml = Editor.get_first_pipeline(page)

      assert get_in(yaml, ["auto_cancel"]) == %{
               "running" => %{"when" => "branch != 'master'"},
               "queued" => %{"when" => "branch = 'master'"}
             }
    end

    browser_test "setting strategy to a custom one", %{page: page} do
      page = page |> change_auto_cancel_type(@strategy_custom)

      running_query = Query.text_field("Cancel both running and queued pipelines when:")
      queued_query = Query.text_field("Cancel only queued pipelines when:")

      page =
        page
        |> Editor.fill(running_query, "branch != 'dev'")
        |> Editor.select_first_pipeline()
        |> Editor.fill(queued_query, "branch != 'test'")
        |> Editor.select_first_pipeline()

      :timer.sleep(600)

      yaml = Editor.get_first_pipeline(page)

      assert get_in(yaml, ["auto_cancel"]) == %{
               "running" => %{"when" => "branch != 'dev'"},
               "queued" => %{"when" => "branch != 'test'"}
             }
    end
  end

  describe "global job config" do
    setup %{page: page} do
      page = page |> Editor.select_first_pipeline() |> Editor.expand_config("Fail-Fast")

      {:ok, %{page: page}}
    end

    browser_test "editing prologue commands", %{page: page} do
      page =
        page
        |> Editor.select_first_pipeline()
        |> Editor.expand_config("Prologue")
        |> Editor.in_config("Prologue", fn cfg ->
          cfg |> fill_in(Query.css("textarea"), with: "echo hello")
        end)
        |> Editor.select_first_pipeline()

      :timer.sleep(500)

      yaml = Editor.get_first_pipeline(page)

      assert get_in(yaml, ["global_job_config", "prologue", "commands"]) == ["echo hello"]
    end

    browser_test "editing epilogue always", %{page: page} do
      page =
        page
        |> Editor.select_first_pipeline()
        |> Editor.expand_config("Epilogue")
        |> Editor.in_config("Epilogue", fn cfg ->
          cfg |> fill_in(Query.text_field("Execute always"), with: "echo always")
        end)
        |> Editor.select_first_pipeline()

      :timer.sleep(600)

      yaml = Editor.get_first_pipeline(page)
      epilogue = get_in(yaml, ["global_job_config", "epilogue"])
      assert get_in(epilogue, ["always", "commands"]) == ["echo always"]
    end

    browser_test "editing epilogue on fail", %{page: page} do
      page =
        page
        |> Editor.select_first_pipeline()
        |> Editor.expand_config("Epilogue")
        |> Editor.in_config("Epilogue", fn cfg ->
          cfg |> fill_in(Query.text_field("If job has failed"), with: "echo fail")
        end)
        |> Editor.select_first_pipeline()

      :timer.sleep(600)

      yaml = Editor.get_first_pipeline(page)
      epilogue = get_in(yaml, ["global_job_config", "epilogue"])
      assert get_in(epilogue, ["on_fail", "commands"]) == ["echo fail"]
    end

    browser_test "editing epilogue on pass", %{page: page} do
      page =
        page
        |> Editor.select_first_pipeline()
        |> Editor.expand_config("Epilogue")
        |> Editor.in_config("Epilogue", fn cfg ->
          cfg |> fill_in(Query.text_field("If job has passed"), with: "echo pass")
        end)
        |> Editor.select_first_pipeline()

      :timer.sleep(600)

      yaml = Editor.get_first_pipeline(page)
      epilogue = get_in(yaml, ["global_job_config", "epilogue"])
      assert get_in(epilogue, ["on_pass", "commands"]) == ["echo pass"]
    end
  end

  #
  # Utils
  #

  def change_fail_fast_type(page, type) do
    page
    |> Editor.in_config("Fail-Fast", fn cfg ->
      cfg
      |> find(Query.select("What to do when a job fails?"), fn select ->
        select |> click(Query.option(type))
      end)
    end)
  end

  def change_auto_cancel_type(page, type) do
    page =
      page
      |> Editor.in_config("Auto-Cancel", fn cfg ->
        select_query =
          Query.select("What to do with previous pipelines on a branch or pull-request?")

        find(cfg, select_query, fn select ->
          select |> click(Query.option(type))
        end)
      end)

    # give a bit time for the app to update before moving on the the next steps
    :timer.sleep(100)

    page
  end
end
