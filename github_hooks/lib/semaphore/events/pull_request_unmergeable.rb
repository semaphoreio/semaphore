module Semaphore::Events
  class PullRequestUnmergeable

    def self.emit(workflow, branch)
      event = InternalApi::RepoProxy::PullRequestUnmergeable.new(
        :project_id => workflow.project_id,
        :branch_name => branch.name,
        :timestamp => ::Google::Protobuf::Timestamp.new(:seconds => Time.now.to_i)
      )

      message = InternalApi::RepoProxy::PullRequestUnmergeable.encode(event)

      options = {
        :exchange => "hook_exchange",
        :routing_key => "pr_unmergeable",
        :url => App.amqp_url
      }

      Logman.info "Publishing pr_unmergeable event for project #{workflow.project_id}, branch #{branch.name}"

      Tackle.publish(message, options)
    end
  end
end
