module Semaphore
  class ProjectIntegrationToken
    def project_token(project)
      case project.repository.integration_type
      when "github_app"
        github_app_token(project.repo_owner_and_name)
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

    def bitbucket_oauth_token(user)
      Semaphore::Bitbucket::Token.user_token(user.bitbucket_repo_host_account)
    end

    def github_app_token(repository_slug)
      Semaphore::GithubApp::Token.repository_token(repository_slug)
    end
  end
end
