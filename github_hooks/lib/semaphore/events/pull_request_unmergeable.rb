module Semaphore::Events
  class PullRequestUnmergeable

    def self.emit(project_id, branch_name)
      event = InternalApi::RepoProxy::PullRequestUnmergeable.new(
        :project_id => project_id,
        :branch_name => branch_name,
        :timestamp => ::Google::Protobuf::Timestamp.new(:seconds => Time.now.to_i)
      )

      message = InternalApi::RepoProxy::PullRequestUnmergeable.encode(event)

      options = {
        :exchange => "hook_exchange",
        :routing_key => "pr_unmergeable",
        :url => App.amqp_url
      }

      Logman.info "Publishing pr_unmergeable event for project #{project_id}, branch #{branch_name}"

      Tackle.publish(message, options)
    end
  end
end
