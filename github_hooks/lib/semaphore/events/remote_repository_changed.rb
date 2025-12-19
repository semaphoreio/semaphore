module Semaphore::Events
  class RemoteRepositoryChanged

    def self.emit(repository_id)
      msg_klass = InternalApi::Repository::RemoteRepositoryChanged

      event = msg_klass.new(
        :repository_id => repository_id,
        :timestamp => ::Google::Protobuf::Timestamp.new(:seconds => Time.now.to_i)
      )

      message = msg_klass.encode(event)

      options = {
        :exchange => "repository_exchange",
        :routing_key => "remote_repository_changed",
        :url => App.amqp_url
      }

      Logman.info "Publishing remote repository changed event for reposotory #{repository_id}"

      Tackle.publish(message, options)
    end
  end
end
