defmodule HooksReceiver.Hook.ValidatorTest do
  use ExUnit.Case
  doctest HooksReceiver.Hook.Validator
  alias HooksReceiver.Hook.Validator

  import Mock

  setup_with_mocks([
    {HooksReceiver.RepositoryClient, [], [describe: &fake_repository_describe/1]},
    {HooksReceiver.OrganizationClient, [], [describe: &fake_organization_describe/1]}
  ]) do
    req_headers = %{
      "x-hub-signature" => "sha1=1234567890",
      "x-gitlab-token" => "sha1=1234567890",
      "x-semaphore-org-id" => "some-org-id",
      "x-event-key" => "repo:push",
      "x-gitlab-event" => "Push Hook"
    }

    hook = %{
      "id" => "some-project-id",
      "webhook" => %{"test_param" => "value"}
    }

    [
      req_headers: req_headers,
      hook: hook
    ]
  end

  describe "#run" do
    test "properly sets a signature for bitbucket", %{req_headers: req_headers, hook: hook} do
      req_headers = Map.delete(req_headers, "x-gitlab-token")
      assert {true, hook_metadata} = Validator.run(:bitbucket, req_headers, hook)
      assert hook_metadata.signature == "sha1=1234567890"
    end

    test "properly sets a signature for gitlab", %{req_headers: req_headers, hook: hook} do
      req_headers = Map.delete(req_headers, "x-hub-signature")
      assert {true, hook_metadata} = Validator.run(:gitlab, req_headers, hook)
      assert hook_metadata.signature == "sha1=1234567890"
    end
  end

  defp fake_repository_describe(_request) do
    {:ok, %{id: "some_repo_id", project_id: "some_project_id"}}
  end

  defp fake_organization_describe(_request) do
    {:ok, %{org_id: "some_org_id", suspended: false}}
  end
end
