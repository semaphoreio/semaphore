module Semaphore::Events
  class RemoteRepositoryChanged

    def self.emit(remote_repository)
      msg_klass = InternalApi::Repository::RemoteRepositoryChanged

      event = msg_klass.new(
        :remote_id => remote_repository["id"].to_s,
        :timestamp => ::Google::Protobuf::Timestamp.new(:seconds => Time.now.to_i)
      )

      message = msg_klass.encode(event)

      options = {
        :exchange => "repository_exchange",
        :routing_key => "remote_repository_changed",
        :url => App.amqp_url
      }

      Logman.info "Publishing remote repository changed event for reposotory #{remote_repository["id"]}"

      Tackle.publish(message, options)
    end
  end
end
