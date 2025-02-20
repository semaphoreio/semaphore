module Semaphore::GithubApp
  class Repositories
    class Worker
      include Sidekiq::Worker

      sidekiq_options :queue => :github_app

      def perform(installation_id)
        log(installation_id, "Start")

        result = Semaphore::GithubApp::Repositories.refresh(installation_id)

        case result
        when :ok
          log(installation_id, "Finish")
        when :no_token
          log(installation_id, "Token not found")
        when :no_installation
          log(installation_id, "Installation not found")
        when :low_rate_limit
          log(installation_id, "Low Rate Limit")
          Semaphore::GithubApp::Repositories::Worker.perform_in(15.minutes, installation_id)
        else
          log(installation_id, "Unknown result: #{result.inspect}")
        end
      end

      private

      def log(installation_id, message)
        Rails.logger.info("[Installation Repository Refresh] #{installation_id}: #{message}")
      end
    end
  end
end
