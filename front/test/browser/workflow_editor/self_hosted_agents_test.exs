defmodule Front.Browser.WorkflowEditor.SelfHostedAgentsTest do
  use FrontWeb.WallabyCase

  alias Support.Browser.WorkflowEditor, as: Editor

  alias Wallaby.Query

  setup %{session: session} do
    Editor.init()

    workflow = Editor.get_workflow()

    Support.Stubs.PermissionPatrol.allow_everything()

    Editor.create_self_hosted_agent("s1-testing-1")
    Editor.create_self_hosted_agent("s1-testing-2")

    page = Editor.open(session, workflow.id)

    {:ok, %{page: page}}
  end

  describe "blocks" do
    setup %{page: page} do
      page =
        page
        |> execute_script("window.confirm = function(){return true;}")
        |> Editor.select_first_block()
        |> Editor.expand_config("Agent")

      {:ok, %{page: page}}
    end

    browser_test "configure self-hosted machine", %{page: page} do
      # enable
      page = page |> click(Query.checkbox("Override global agent definition"))
      page = page |> Editor.change_agent_env_type_for_block("Self-Hosted Machine")

      yaml = Editor.first_block_yaml(page)
      assert get_in(yaml, ["task", "agent", "containers"]) == nil
      assert get_in(yaml, ["task", "agent", "machine", "type"]) == "s1-testing-1"
    end
  end

  describe "pipeline" do
    setup %{page: page} do
      page =
        page
        |> execute_script("window.confirm = function(){return true;}")
        |> Editor.select_first_pipeline()

      {:ok, %{page: page}}
    end

    browser_test "configure self-hosted machine", %{page: page} do
      page = page |> Editor.change_agent_env_type_for_pipeline("Self-Hosted Machine")

      page =
        page
        |> click(Query.radio_button("s1-testing-2"))

      yaml = Editor.get_first_pipeline(page)
      assert get_in(yaml, ["agent", "containers"]) == nil
      assert get_in(yaml, ["agent", "machine", "type"]) == "s1-testing-2"
    end
  end
end
