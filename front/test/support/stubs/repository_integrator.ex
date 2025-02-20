defmodule Support.Stubs.RepositoryIntegrator do
  def init do
    get_repositories_response =
      InternalApi.RepositoryIntegrator.GetRepositoriesResponse.new(
        repositories: [
          InternalApi.RepositoryIntegrator.Repository.new(
            addable: true,
            name: "guard",
            full_name: "renderedtext/guard",
            url: "git://github.com/renderedtext/guard",
            description: ""
          )
        ]
      )

    check_token_response =
      InternalApi.RepositoryIntegrator.CheckTokenResponse.new(
        valid: true,
        integration_scope:
          InternalApi.RepositoryIntegrator.IntegrationScope.value(:FULL_CONNECTION)
      )

    github_installation_info_response =
      InternalApi.RepositoryIntegrator.GithubInstallationInfoResponse.new(
        installation_id: 13_675_798,
        installation_url:
          "https://github.com/organizations/renderedtext/settings/installations/13675798",
        application_url: "https://github.com/apps/semaphore-test-app"
      )

    get_file_response = InternalApi.RepositoryIntegrator.GetFileResponse.new(content: "")

    GrpcMock.stub(RepositoryIntegratorMock, :get_repositories, get_repositories_response)
    GrpcMock.stub(RepositoryIntegratorMock, :check_token, check_token_response)
    GrpcMock.stub(RepositoryIntegratorMock, :get_file, get_file_response)

    GrpcMock.stub(
      RepositoryIntegratorMock,
      :github_installation_info,
      github_installation_info_response
    )
  end
end
