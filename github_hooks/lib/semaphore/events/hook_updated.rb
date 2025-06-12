module Semaphore::Events
  class HookUpdated

    def self.emit(branch, workflow)
      event = InternalApi::RepoProxy::HookUpdated.new(
        :hook_id => workflow.id,
        :project_id => workflow.project_id,
        :timestamp => ::Google::Protobuf::Timestamp.new(:seconds => Time.now.to_i)
      )

      message = InternalApi::RepoProxy::HookUpdated.encode(event)

      options = {
        :exchange => "hook_exchange",
        :routing_key => "updated",
        :url => App.amqp_url
      }

      Logman.info "Publishing hook updated event for hook #{hook.id}, project #{workflow.project_id}"

      Tackle.publish(message, options)
    end
  end
end
