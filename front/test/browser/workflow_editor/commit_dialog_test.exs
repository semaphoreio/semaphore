defmodule Front.Browser.WorkflowEditor.CommitDialogTest do
  use FrontWeb.WallabyCase

  alias Support.Browser
  alias Support.Browser.WorkflowEditor, as: Editor

  setup %{session: session} do
    Editor.init()

    Support.Stubs.PermissionPatrol.allow_everything()

    workflow = Editor.get_workflow()

    page = Editor.open(session, workflow.id)

    {:ok, %{page: page}}
  end

  browser_test "dismiss and exit editor goes back to workflow page", %{page: page} do
    page =
      page
      |> Browser.disable_onbeforeunload_dialog()
      |> click(Query.css("a", text: "Dismiss and Exit"))

    {:ok, path} = Browser.get_current_path(page)

    assert path =~ ~r/^\/workflows\/[a-zA-Z0-9-]+$/
  end

  describe "filling in the branch name and commit message and clicking submit" do
    browser_test "when the action succeds => it redirects to workflow", %{page: page} do
      user = Support.Stubs.User.create_default()
      org = Support.Stubs.Organization.create_default()
      Support.Stubs.Feature.enable_feature(org.id, :permission_patrol)
      Support.Stubs.PermissionPatrol.allow_everything(org.id, user.id)

      summary = Query.css("#workflow-editor-commit-dialog-summary")
      branch = Query.css("#workflow-editor-commit-dialog-branch")

      page =
        page
        |> click(Query.css("a", text: "Run the workflow"))
        |> fill_in(summary, with: "My message")
        |> fill_in(branch, with: "develop")
        |> click(Query.css("a", text: "Start →"))

      create_fake_workflow(
        "develop",
        Support.Stubs.Repository.commit_response_sha()
      )

      :timer.sleep(1000)

      {:ok, path} = Browser.get_current_path(page)

      assert path =~ ~r/^\/workflows\/[a-zA-Z0-9-]+$/
    end
  end

  def create_fake_workflow(_branch, commit_sha) do
    alias Support.FakeServices, as: FS

    workflow =
      InternalApi.PlumberWF.WorkflowDetails.new(
        wf_id: "9a22a11e-6479-4740-8666-939795c842e9",
        branch_name: "develop",
        commit_sha: commit_sha,
        created_at: Google.Protobuf.Timestamp.new(seconds: 1, nanos: 2)
      )

    workflow_list_response =
      InternalApi.PlumberWF.ListResponse.new(
        workflows: [workflow],
        status: Support.Factories.internal_api_status_ok(),
        page_number: 1,
        total_pages: 1
      )

    FunRegistry.set!(FS.WorkflowService, :list, workflow_list_response)
  end
end
