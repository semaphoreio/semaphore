defmodule GithubNotifier.Utils.Url.Test do
  use ExUnit.Case

  alias GithubNotifier.Utils.Url

  test "when project and pipeline_id is passed => returns url to pipeline in organization" do
    project = %{org_id: "123"}
    workflow_id = "1234"
    ppl_id = "12345"

    GrpcMock.stub(
      OrganizationMock,
      :describe,
      InternalApi.Organization.DescribeResponse.new(
        status: Support.Factories.status_ok(),
        organization:
          InternalApi.Organization.Organization.new(
            org_username: "renderedtext",
            org_id: "123"
          )
      )
    )

    assert Url.prepare(project, workflow_id, ppl_id) ==
             "https://renderedtext.semaphoreci.local/workflows/1234?pipeline_id=12345"
  end
end
