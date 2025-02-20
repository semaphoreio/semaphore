module Semaphore::GithubApp
  class Collaborators
    class Worker
      include Sidekiq::Worker

      sidekiq_options :queue => :github_app

      def perform(slug)
        log(slug, "Start")

        if slug.blank?
          log(slug, "Empty")
          return
        end

        result = Semaphore::GithubApp::Collaborators.refresh(slug)

        case result
        when :ok
          log(slug, "Finish")
        when :no_token
          log(slug, "Token not found")
        when :no_repository
          log(slug, "Repository not found on GitHub")
        when :low_rate_limit
          log(slug, "Low Rate Limit")
          Semaphore::GithubApp::Collaborators::Worker.perform_in(15.minutes, slug)
        else
          log(slug, "Unknown result: #{result.inspect}")
        end
      end

      private

      def log(slug, message)
        Rails.logger.info("[Repository Collaborators Refresh] #{slug}: #{message}")
      end
    end
  end
end
