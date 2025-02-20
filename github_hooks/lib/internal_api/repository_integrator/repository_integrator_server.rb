module InternalApi
  module RepositoryIntegrator
    class RepositoryIntegratorServer < RepositoryIntegratorService::Service
      extend InternalApi::GrpcDsl
      include Semaphore::Grpc::Timestamp

      rpc_metric_namespace "repository_integrators_api"

      define_rpc :preheat_file_cache do |req, logger|
        project = ::Project.find(req.project_id)

        cache_content(project, req.path, req.ref, logger)

        Google::Protobuf::Empty.new
      rescue ActiveRecord::RecordNotFound
        Google::Protobuf::Empty.new
      end

      define_rpc :get_file do |req, logger|
        project = ::Project.find(req.project_id)

        value = get_content(project, req.path, req.ref, logger)

        case value[0]
        when :ok
          InternalApi::RepositoryIntegrator::GetFileResponse.new(
            :content => value[1]
          )
        when :error
          raise GRPC::NotFound, value[1]
        end
      rescue ActiveRecord::RecordNotFound
        raise GRPC::NotFound, "Project with id #{req.project_id} not found."
      end

      define_rpc :get_token do |req|
        token, expires_at = fetch_token(req)

        InternalApi::RepositoryIntegrator::GetTokenResponse.new(
          :token => token,
          :expires_at => grpc_timestamp(expires_at)
        )
      end

      define_rpc :get_repositories do |req|
        user = ::User.find(req.user_id)
        github_uid = user.github_repo_host_account.github_uid
        repositories = ::GithubAppCollaborator.where(:c_id => github_uid)

        InternalApi::RepositoryIntegrator::GetRepositoriesResponse.new(
          :repositories => repositories.map do |repository|
            InternalApi::RepositoryIntegrator::Repository.new(
              :addable => true,
              :name => extract_repository_name(repository.r_name),
              :full_name => repository.r_name,
              :url => map_repository_url(repository.r_name),
              :description => ""
            )
          end
        )
      rescue ActiveRecord::RecordNotFound
        InternalApi::RepositoryIntegrator::GetRepositoriesResponse.new(
          :repositories => []
        )
      end

      define_rpc :github_installation_info do |req|
        project = ::Project.find(req.project_id)
        installation = ::GithubAppInstallation.find_for_repository(project.repo_owner_and_name)

        InternalApi::RepositoryIntegrator::GithubInstallationInfoResponse.new(
          :installation_id => installation ? installation.installation_id : 0,
          :installation_url => installation ? "https://github.com/organizations/#{project.repo_owner}/settings/installations/#{installation.installation_id}" : "",
          :application_url => App.github_application_url
        )
      rescue ActiveRecord::RecordNotFound
        raise GRPC::NotFound, "Project with id #{req.project_id} not found."
      end

      define_rpc :init_github_installation do |_req|
        ::Semaphore::GithubApp::Installations.init

        ::InternalApi::RepositoryIntegrator::InitGithubInstallationResponse.new
      end

      define_rpc :check_token do |req|
        project = ::Project.find(req.project_id)

        if project.repository.integration_type == "github_app"
          installation = ::GithubAppInstallation.find_for_repository(project.repo_owner_and_name)
          valid = installation.present?

          if installation.present?
            scope = InternalApi::RepositoryIntegrator::IntegrationScope::FULL_CONNECTION
          else
            scope = InternalApi::RepositoryIntegrator::IntegrationScope::NO_CONNECTION
          end
        else
          connection = update_revoke_status(project.repo_host_account)
          repository = project.repository

          if connection.revoked?
            scope = InternalApi::RepositoryIntegrator::IntegrationScope::NO_CONNECTION
          elsif connection.private_scope?
            scope = InternalApi::RepositoryIntegrator::IntegrationScope::FULL_CONNECTION
          elsif connection.public_scope?
            scope = InternalApi::RepositoryIntegrator::IntegrationScope::ONLY_PUBLIC
          else
            scope = InternalApi::RepositoryIntegrator::IntegrationScope::NO_CONNECTION
          end

          if connection.revoked?
            valid = false
          elsif repository.private? && !connection.private_scope?
            valid = false
          elsif !connection.public_scope?
            valid = false
          else
            valid = true
          end
        end

        InternalApi::RepositoryIntegrator::CheckTokenResponse.new(
          :valid => valid,
          :integration_scope => scope
        )
      rescue ActiveRecord::RecordNotFound
        raise GRPC::NotFound, "Project with id #{req.project_id} not found."
      end

      private

      def update_revoke_status(rha)
        if rha.repo_host == "github"
          rha.update!(:revoked => !::RepoHost::Github::Client.new(rha.token).token_valid?)
        end

        if rha.repo_host == "bitbucket"
          token, _ = ::Semaphore::Bitbucket::Token.user_token(rha)
          rha.update!(:revoked => !::Semaphore::Bitbucket::Token.valid?(token))
        end

        rha
      end

      def extract_repository_name(full_name)
        full_name.split("/").last
      end

      def map_repository_url(full_name)
        "git://github.com/#{full_name}.git"
      end

      def cache_content(project, path, ref, logger)
        re = Regexp.new("\\A[a-z0-9]{40}\\z").freeze
        use_cache = re.match?(ref.to_s)
        return unless use_cache

        cache_key = cache_key(project, path, ref)

        value = get_content_(project, path, ref, logger)
        Rails.cache.write(cache_key, value, :expires_in => 5.minutes)

        value
      end

      def get_content(project, path, ref, logger)
        re = Regexp.new("\\A[a-z0-9]{40}\\z").freeze
        use_cache = re.match?(ref.to_s)
        return get_content_(project, path, ref, logger) unless use_cache

        cache_key = cache_key(project, path, ref)

        value = Watchman.benchmark("get_file.read_cache") do
          Rails.cache.read(cache_key)
        end

        if value.nil?
          value = cache_content(project, path, ref, logger)

          Watchman.increment("get_file.cache_miss")
        else
          Watchman.increment("get_file.cache_hit")
        end

        value
      end

      def cache_key(project, path, ref)
        "v2.#{project.id}/#{project.repo_owner_and_name}/#{path}/#{ref}"
      end

      def get_content_(project, path, ref, logger)
        token = Watchman.benchmark("get_file.get_token") do
          token_service = ::Semaphore::ProjectIntegrationToken.new
          token, = token_service.project_token(project)
          token
        end

        Watchman.benchmark("get_file.fetch_content") do
          client = ::RepoHost::Github::Client.new(token)
          resource = client.contents(
            project.repo_owner_and_name,
            path,
            ref.presence,
            true
          )

          [:ok, resource.content.delete("\n")]
        rescue Octokit::Error => e
          response_message = e.send(:response_message).presence || "Problem with connection to the repository."

          logger.info "Repository Connection Error: #{project.id} => #{response_message}, #{e.message}"

          [:error, response_message]
        end
      end

      def fetch_token(req)
        token_service = ::Semaphore::ProjectIntegrationToken.new

        if req.integration_type == :GITHUB_OAUTH_TOKEN and req.user_id.present?
          user = ::User.find_by(:id => req.user_id)
          raise GRPC::NotFound, "User with id #{req.user_id} not found." unless user

          return token_service.github_oauth_token(user)
        end

        if req.integration_type == :BITBUCKET and req.user_id.present?
          user = ::User.find_by(:id => req.user_id)
          raise GRPC::NotFound, "User with id #{req.user_id} not found." unless user

          return token_service.bitbucket_oauth_token(user)
        end

        if req.integration_type == :GITHUB_APP and req.repository_slug.present?
          return token_service.github_app_token(req.repository_slug)
        end

        if req.project_id.present?
          project = ::Project.find_by(:id => req.project_id)
          raise GRPC::NotFound, "Project with id #{req.project_id} not found." unless project

          return token_service.project_token(project)
        end

        raise GRPC::FailedPrecondition, "One of user_id, repository_slug or project_id is required."
      end
    end
  end
end
