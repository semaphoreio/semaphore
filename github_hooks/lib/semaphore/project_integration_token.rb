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
      when "gitlab"
        user = ::User.find(project.creator_id)
        gitlab_oauth_token(user)
      else
        user = ::User.find(project.creator_id)
        github_oauth_token(user)
      end
    end

    def github_oauth_token(user)
      [user.github_repo_host_account.token, nil]
    end

    def bitbucket_oauth_token(user)
      guard_oauth_token(user, "bitbucket")
    end

    def gitlab_oauth_token(user)
      guard_oauth_token(user, "gitlab")
    end

    def github_app_token(repository_slug: nil, repository_remote_id: nil)
      Semaphore::GithubApp::Token.repository_token(
        :repository_slug => repository_slug,
        :repository_remote_id => repository_remote_id
      )
    end

    private

    # guard is the only component that may refresh these, and the stored row can
    # already be past its expiry, so ask guard rather than reading it. Keeps the
    # ["", nil] shape on failure: get_token puts this in a proto3 string field,
    # which rejects nil.
    def guard_oauth_token(user, integration_type)
      Semaphore::GuardUserClient.repository_token(user.id, integration_type)
    rescue StandardError => e
      Rails.logger.info(
        "[ProjectIntegrationToken] no usable #{integration_type} token " \
        "for user #{user.id}: #{e.class}"
      )

      ["", nil]
    end
  end
end
