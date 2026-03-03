module Semaphore::GithubApp
  class Repositories
    class RemoteIdBackfill
      class Worker
        include Sidekiq::Worker

        sidekiq_options :queue => :github_app

        def perform(installation_id = nil)
          result = if installation_id.present?
                     Semaphore::GithubApp::Repositories::RemoteIdBackfill.refresh_installation(installation_id)
                   else
                     Semaphore::GithubApp::Repositories::RemoteIdBackfill.refresh_next_installation
                   end

          handle_result(result)
        end

        private

        def handle_result(result)
          installation_id = result[:installation_id]

          case result[:status]
          when :ok
            log(installation_id, "Finish (updated=#{result[:updated_count]})")
          when :nothing_to_do
            log(installation_id, "Nothing to do")
          when :lock_not_acquired
            log(installation_id, "Skipped, lock not acquired")
          when :no_token
            log(installation_id, "Token not found")
          when :no_installation
            log(installation_id, "Installation not found")
          when :low_rate_limit
            log(installation_id, "Low Rate Limit")
            self.class.perform_in(15.minutes, installation_id)
          else
            log(installation_id, "Unknown result: #{result.inspect}")
          end
        end

        def log(installation_id, message)
          Rails.logger.info("[Installation Repository RemoteId Backfill] #{installation_id}: #{message}")
        end
      end
    end
  end
end
