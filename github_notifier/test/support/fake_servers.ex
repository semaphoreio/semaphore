defmodule GithubNotifier.FakeServers do
  def setup_responses_for_development do
    GrpcMock.stub(PipelineMock, :describe, Support.Factories.pipeline_describe_response())
    GrpcMock.stub(ProjecthubMock, :describe, Support.Factories.project_describe_response())
    GrpcMock.stub(UserMock, :describe, Support.Factories.user_describe_response())
    GrpcMock.stub(OrganizationMock, :describe, Support.Factories.organization_describe_response())
    GrpcMock.stub(RepoProxyMock, :describe, Support.Factories.repo_proxy_describe_response())
    GrpcMock.stub(RepositoryHubMock, :create_build_status, Google.Protobuf.Empty.new())

    GrpcMock.stub(
      FeatureMock,
      :list_organization_features,
      Support.Factories.feature_list_response()
    )

    GrpcMock.stub(
      RepositoryIntegratorMock,
      :get_token,
      Support.Factories.repo_integrator_get_token_response()
    )
  end
end
