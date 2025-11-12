defmodule Front.Browser.WorkflowEditor.CodeEditorTest do
  use FrontWeb.WallabyCase

  alias Support.Browser.WorkflowEditor, as: Editor

  import Wallaby.Query, only: [css: 1]

  @broken_yaml """
  version: 1.0
  agent:
    machine:
      type: "ubuntu1804"
       os_image: ""
  """

  @good_yaml """
  version: 1.0
  agent:
    machine:
      type: "ubuntu1804"
      os_image: ""
  """

  setup %{session: session} do
    Editor.init()

    Support.Stubs.PermissionPatrol.allow_everything()

    workflow = Editor.get_workflow()

    page = Editor.open(session, workflow.id)

    {:ok, %{page: page}}
  end

  browser_test "YAML validation errors in code editor", %{page: page} do
    page
    |> Editor.change_code_in_editor("semaphore.yml", @broken_yaml)
    |> assert_has(css(".CodeMirror-lint-marker-error"))
    |> Editor.change_code_in_editor("semaphore.yml", @good_yaml)
    |> refute_has(css(".CodeMirror-lint-marker-error"))
  end

  browser_test "YAML validation errors on diagram", %{page: page} do
    error_message = "bad indentation of a mapping entry"
    error_title = "Invalid YAML syntax in .semaphore/semaphore.yml"

    # assert that error appears on diagram page if a YAML has syntax error
    page =
      page
      |> Editor.change_code_in_editor("semaphore.yml", @broken_yaml)
      |> Editor.goto_visual_editor()
      |> assert_has(Query.css("#workflow-editor-diagram", text: error_title))
      |> assert_has(Query.css("#workflow-editor-diagram", text: error_message))

    # # assert that error disappears on diagram page if the error is fixed

    page
    |> Editor.change_code_in_editor("semaphore.yml", @good_yaml)
    |> Editor.goto_visual_editor()
    |> refute_has(Query.css("#workflow-editor-diagram", text: error_title))
    |> refute_has(Query.css("#workflow-editor-diagram", text: error_message))
  end
end
