module Semaphore
  class ProjectIntegrationToken
    def project_token(project)
      case project.repository.integration_type
      when "github_app"
        github_app_token(
          :repository_slug => project.repo_owner_and_name,
          :repository_remote_id => project.repository.remote_id
        )
      when "bitbucket"
        user = ::User.find(project.creator_id)
        bitbucket_oauth_token(user)
      else
        user = ::User.find(project.creator_id)
        github_oauth_token(user)
      end
    end

    def github_oauth_token(user)
      [user.github_repo_host_account.token, nil]
    end

    # Returns the stored credential. Never refresh here: Bitbucket refresh
    # tokens are single-use and rotating, and guard owns that lifecycle.
    def bitbucket_oauth_token(user)
      rha = user.bitbucket_repo_host_account

      # get_token puts this in a proto3 string field, which rejects nil.
      return ["", nil] if rha.nil?

      [rha.token.to_s, rha.token_expires_at]
    end

    def github_app_token(repository_slug: nil, repository_remote_id: nil)
      Semaphore::GithubApp::Token.repository_token(
        :repository_slug => repository_slug,
        :repository_remote_id => repository_remote_id
      )
    end
  end
end
