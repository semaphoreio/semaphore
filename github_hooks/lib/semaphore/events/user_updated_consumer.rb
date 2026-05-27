module Semaphore::Events
  #
  # Tackle consumer that subscribes to the `user_exchange` / `updated` route
  # published by Guard and dispatches to {UserUpdatedHandler}.
  #
  # Started from the rake task `rake amqp:consumers:user_updated` (or via the
  # service-wide consumer runner used in production - see deployment manifest).
  #
  class UserUpdatedConsumer < Tackle::Consumer
    def options
      {
        :url => App.amqp_url,
        :exchange => "user_exchange",
        :routing_key => "updated",
        :service => "github_hooks.user_updated"
      }
    end

    def handle_message(message)
      event = InternalApi::User::UserUpdated.decode(message)

      Logman.info("[UserUpdatedConsumer] Received user_id=#{event.user_id}")

      UserUpdatedHandler.call(event.user_id)
    rescue StandardError => e
      Logman.error(
        "[UserUpdatedConsumer] Failed to process message: #{e.class}: #{e.message}"
      )
      Sentry.capture_exception(e)
      raise
    end
  end
end
