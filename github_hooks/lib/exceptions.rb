module Exceptions

  class GitHubError < RuntimeError
  end

  class GitHubUnauthorized < RuntimeError
  end

  class EmailSendingError < RuntimeError
  end

  class EmailTimeoutError < RuntimeError
  end

  module_function

  def notify(exception, custom_data = {})
    if Rails.env.test? || Rails.env.development?
      Rails.logger.error(exception.try(:message))
      Rails.logger.error(custom_data.inspect)

      backtrace = exception.try(:backtrace) || []
      Rails.logger.error(backtrace.join("\n"))
    else
      Sentry.with_scope do |scope|
        scope.set_tags(:application => 'front')
        scope.set_context('extra', custom_data)
        Sentry.capture_exception(exception)
      end
    end
  end

  def set_user_context(user_context)
    Sentry.set_user(user_context)
  end

  def set_custom_context(name, context)
    Sentry.set_context(name, context)
  end
end
