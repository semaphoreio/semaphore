module Semaphore::Events
  class ProjectCollaboratorsChanged
    include Sidekiq::Worker

    sidekiq_options :queue => :rabbitmq, :retry => 5

    def self.emit(project_id)
      perform_async(project_id)
    end

    def perform(project_id)
      msg_klass = InternalApi::Projecthub::CollaboratorsChanged

      event = msg_klass.new(
        :project_id => project_id,
        :timestamp => ::Google::Protobuf::Timestamp.new(:seconds => Time.now.to_i)
      )

      message = msg_klass.encode(event)

      options = {
        :exchange => "project_exchange",
        :routing_key => "collaborators_changed",
        :url => App.amqp_url
      }

      Logman.info "Publishing project collaborators changed event for project #{project_id}"

      Tackle.publish(message, options)
    end
  end
end
