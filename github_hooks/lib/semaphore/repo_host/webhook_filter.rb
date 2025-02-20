module Semaphore::RepoHost
  class WebhookFilter
    def self.create_webhook_filter(request, payload)
      if request.github?
        Semaphore::RepoHost::Github::WebhookFilter.new(request, payload)
      elsif request.semaphore?
        Semaphore::RepoHost::NoPassFilter.new(request, payload)
      end
    end
  end
end
