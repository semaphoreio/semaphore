defmodule HooksProcessor.Hooks.Payload.ApiTest do
  use ExUnit.Case

  alias HooksProcessor.Hooks.Payload.Api, as: ApiPayload
  alias Support.ApiHooks

  test "hook_type() returns proper hook type for all types of hooks" do
    assert ApiHooks.tag() |> ApiPayload.hook_type() == "tag"

    assert ApiHooks.branch() |> ApiPayload.hook_type() == "branch"
  end

  test "extract_data() returns valid data set for each type of the hook" do
    data = ApiHooks.tag() |> ApiPayload.extract_data()
    assert data.branch_name == "refs/tags/v1.0.1"
    assert data.git_ref == "refs/tags/v1.0.1"
    assert data.display_name == "v1.0.1"
    assert data.owner == "renderedtext"
    assert data.repo_name == "alles"
    assert data.commit_sha == "023becf74ae8a5d93911db4bad7967f94343b44b"
    assert data.commit_message == "Initial commit"
    assert data.commit_author == "radwo"
    assert data.pr_name == ""
    assert data.pr_number == 0

    data = ApiHooks.branch() |> ApiPayload.extract_data()
    assert data.branch_name == "master"
    assert data.git_ref == "refs/heads/master"
    assert data.display_name == "master"
    assert data.owner == "renderedtext"
    assert data.repo_name == "alles"
    assert data.commit_sha == "023becf74ae8a5d93911db4bad7967f94343b44b"
    assert data.commit_message == "Initial commit"
    assert data.commit_author == "radwo"
    assert data.pr_name == ""
    assert data.pr_number == 0
  end
end
