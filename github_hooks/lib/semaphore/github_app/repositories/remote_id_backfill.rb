module Semaphore::GithubApp
  class Repositories
    class RemoteIdBackfill
      MAX_NUMBER_OF_REPOSITORIES = Semaphore::GithubApp::Repositories::MAX_NUMBER_OF_REPOSITORIES
      QUERY_BATCH_SIZE = 500
      ADVISORY_LOCK_NAMESPACE = 71_104

      def self.refresh_next_installation
        new.refresh_next_installation
      end

      def self.refresh_installation(installation_id)
        new.refresh_installation(installation_id)
      end

      def refresh_next_installation
        installation_id = next_pending_installation_id
        return { :status => :nothing_to_do } unless installation_id

        refresh_locked_installation(installation_id)
      ensure
        release_lock(installation_id) if installation_id
      end

      def refresh_installation(installation_id)
        installation_id = installation_id.to_i
        return { :status => :nothing_to_do } if installation_id <= 0
        return { :status => :lock_not_acquired, :installation_id => installation_id } unless try_lock(installation_id)

        refresh_locked_installation(installation_id)
      ensure
        release_lock(installation_id) if installation_id.to_i.positive?
      end

      private

      def next_pending_installation_id
        pending_installation_ids.each do |installation_id|
          return installation_id if try_lock(installation_id)
        end

        nil
      end

      def pending_installation_ids
        GithubAppInstallationRepository
          .where(:remote_id => 0)
          .group(:installation_id)
          .order(Arel.sql("MIN(updated_at) ASC"), :installation_id)
          .limit(QUERY_BATCH_SIZE)
          .pluck(:installation_id)
      end

      def refresh_locked_installation(installation_id)
        @current_installation_id = installation_id

        return token_not_found(installation_id) unless client(installation_id)
        return low_rate_limit(installation_id) if client(installation_id).rate_limit_remaining < App.collaborators_api_rate_limit

        pending_repositories_by_slug = pending_repositories_for_installation(installation_id)
        return ok_result(installation_id, 0) if pending_repositories_by_slug.empty?

        updates = build_updates(pending_repositories_by_slug)
        update_remote_ids(updates)
        touch_pending_repositories(installation_id) if updates.empty?

        ok_result(installation_id, updates.length)
      rescue ActiveRecord::RecordNotFound
        { :status => :no_installation, :installation_id => installation_id }
      end

      def pending_repositories_for_installation(installation_id)
        GithubAppInstallation.find_by!(:installation_id => installation_id)

        GithubAppInstallationRepository
          .where(:installation_id => installation_id, :remote_id => 0)
          .pluck(:id, :slug)
          .each_with_object({}) do |(id, slug), repositories|
            repositories[canonical_slug(slug)] = id
          end
      end

      def build_updates(pending_repositories_by_slug)
        remote_repositories.each_with_object([]) do |repository, updates|
          local_repository_id = pending_repositories_by_slug[canonical_slug(repository["slug"])]
          next unless local_repository_id

          remote_id = repository["id"].to_i
          next if remote_id <= 0

          updates << [local_repository_id, remote_id]
        end
      end

      def update_remote_ids(updates)
        return if updates.empty?

        connection = GithubAppInstallationRepository.connection

        updates.each_slice(QUERY_BATCH_SIZE) do |batch|
          payload = batch.map { |id, remote_id| { :id => id, :remote_id => remote_id.to_i } }.to_json
          bind = ActiveRecord::Relation::QueryAttribute.new(
            "updates_payload",
            payload,
            ActiveRecord::Type::Value.new
          )

          sql = <<~SQL.squish
            UPDATE github_app_installation_repositories AS repositories
            SET remote_id = updates.remote_id,
                updated_at = NOW()
            FROM jsonb_to_recordset($1::jsonb) AS updates(id uuid, remote_id bigint)
            WHERE repositories.id = updates.id
              AND repositories.remote_id = 0
          SQL

          connection.exec_update(sql, "GitHub App RemoteId Backfill", [bind])
        end
      end

      def touch_pending_repositories(installation_id)
        # rubocop:disable Rails/SkipsModelValidations
        GithubAppInstallationRepository
          .where(:installation_id => installation_id, :remote_id => 0)
          .update_all("updated_at = NOW()")
        # rubocop:enable Rails/SkipsModelValidations
      end

      def ok_result(installation_id, updated_count)
        {
          :status => :ok,
          :installation_id => installation_id,
          :updated_count => updated_count,
          :remaining_installations => GithubAppInstallationRepository.where(:remote_id => 0).exists?
        }
      end

      def token_not_found(installation_id)
        { :status => :no_token, :installation_id => installation_id }
      end

      def low_rate_limit(installation_id)
        { :status => :low_rate_limit, :installation_id => installation_id }
      end

      def remote_repositories
        @remote_repositories ||= remote_repositories_from_github
      end

      def remote_repositories_from_github
        github_repos = []
        page = 1
        per_page = 100

        loop do
          response = Excon.get(
            "https://api.github.com/installation/repositories?per_page=#{per_page}&page=#{page}",
            :headers => {
              "User-Agent" => "Monolith-GitHubApp-RepositoryRemoteIdBackfill",
              "Authorization" => "token #{token(@current_installation_id)}",
              "Accept" => "application/vnd.github.v3+json"
            }
          )

          body = JSON.parse(response.data[:body])
          total_count = [body["total_count"].to_i, MAX_NUMBER_OF_REPOSITORIES].min

          github_repos.concat(Semaphore::GithubApp::Hook.map_repositories(body["repositories"]))
          break if page * per_page >= total_count

          page += 1
          sleep 1
        end

        github_repos
      end

      def client(installation_id)
        return @client if defined?(@client)

        installation_token = token(installation_id)
        @client = installation_token ? RepoHost::Github::Client.new(installation_token) : nil
      end

      def token(installation_id)
        return @token if defined?(@token)

        value = Semaphore::GithubApp::Token.installation_token(installation_id)
        @token = value.is_a?(Array) ? value.first : value
      end

      def canonical_slug(slug)
        GithubAppInstallation.canonical_slug(slug)
      end

      def try_lock(installation_id)
        sql = "SELECT pg_try_advisory_lock(#{ADVISORY_LOCK_NAMESPACE}, #{installation_id.to_i})"
        ActiveRecord::Type::Boolean.new.cast(ActiveRecord::Base.connection.select_value(sql))
      end

      def release_lock(installation_id)
        sql = "SELECT pg_advisory_unlock(#{ADVISORY_LOCK_NAMESPACE}, #{installation_id.to_i})"
        ActiveRecord::Base.connection.select_value(sql)
      rescue StandardError
        nil
      end
    end
  end
end
