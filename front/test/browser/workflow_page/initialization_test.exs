defmodule Front.Browser.WorkflowPage.InitializationTest do
  use FrontWeb.WallabyCase

  setup data do
    stubs = Support.Browser.WorkflowPage.create_workflow()

    Support.Stubs.PermissionPatrol.allow_everything()

    context = Map.merge(data, stubs)

    Support.Stubs.Pipeline.change_state(context.pipeline.id, :initializing)

    {:ok, context}
  end

  browser_test "no compilation step => display nothing", context do
    page = open(context)

    refute has_text?(page, "Initializing")
    refute has_text?(page, "Initialization")
  end

  browser_test "compile exists, not yet started => display the message with 00:00 timer",
               context do
    Support.Stubs.Pipeline.add_compile_task(context.pipeline.id)
    Cacheman.clear(:front)

    page = open(context)

    page
    |> find(Query.css("[data-init-header]"))
    |> assert_has(Query.text("Initializing"))
    |> assert_has(Query.text("00:00"))

    Support.Browser.WorkflowPage.stop_polling(page)

    page
    |> find(Query.css("[data-init-header]"))
    |> refute_has(Query.text("See Log"))

    page
    |> assert_has(Query.text("Preparing pipeline"))
    |> assert_has(Query.text("Cloning your reposi"))
  end

  browser_test "compile step exists and finished", context do
    task = Support.Stubs.Pipeline.add_compile_task(context.pipeline.id)
    Support.Stubs.Task.change_state(task, :finished)
    Support.Stubs.Pipeline.change_state(context.pipeline.id, :running)

    page = open(context)

    page
    |> find(Query.css("[data-init-header]"))
    |> assert_has(Query.text("Initialization"))
    |> assert_has(Query.text("00:0"))
    |> assert_has(Query.text("See Log"))

    page
    |> refute_has(Query.text("Preparing pipeline"))
    |> refute_has(Query.text("Cloning your reposi"))
  end

  browser_test "transitioning from initializing -> running expands the promotions as well",
               context do
    task = Support.Stubs.Pipeline.add_compile_task(context.pipeline.id)

    page = open(context)

    # promotions are not yet visible
    refute has_text?(page, "Production")

    # change the state and wait for pollman to refresh
    Support.Stubs.Pipeline.change_state(context.pipeline.id, :running)
    Support.Stubs.Task.change_state(task, :finished)

    # promotions should be visible when the pipeline starts
    assert has_text?(page, "Production")
  end

  defp open(params) do
    path = "/workflows/#{params.workflow.id}?pipeline_id=#{params.pipeline.id}"

    params.session |> visit(path)
  end
end
