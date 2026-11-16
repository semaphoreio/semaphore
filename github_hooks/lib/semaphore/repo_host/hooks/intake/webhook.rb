module Semaphore::RepoHost::Hooks::Intake
  # One accepted hook for one project. Its message is one JSON line of metadata followed by
  # the request body exactly as received, because the signature covers those bytes and
  # tackle keeps only the message body when it retries a hook.
  class Webhook
    FORM_CONTENT_TYPE = "application/x-www-form-urlencoded".freeze

    attr_reader :workflow_id, :project_id, :hash_id, :event, :delivery_id, :signature,
                :content_type, :received_at, :body

    def initialize(workflow_id:, project_id:, body:, signature:, content_type:, received_at:, hash_id: nil, event: nil, delivery_id: nil) # rubocop:disable Metrics/ParameterLists
      @workflow_id = workflow_id
      @project_id = project_id
      @body = body
      @signature = signature
      @content_type = content_type
      @received_at = received_at
      @hash_id = hash_id
      @event = event
      @delivery_id = delivery_id
    end

    def self.from_message(message)
      metadata, body = message.b.split("\n", 2)
      fields = JSON.parse(metadata)

      new(
        :workflow_id => fields["workflow_id"],
        :project_id => fields["project_id"],
        :body => body.to_s,
        :signature => fields["signature"],
        :content_type => fields["content_type"],
        :received_at => Time.zone.parse(fields["received_at"].to_s),
        :hash_id => fields["hash_id"],
        :event => fields["event"],
        :delivery_id => fields["delivery_id"]
      )
    end

    def to_message
      metadata = {
        "workflow_id" => workflow_id,
        "project_id" => project_id,
        "hash_id" => hash_id,
        "event" => event,
        "delivery_id" => delivery_id,
        "signature" => signature,
        "content_type" => content_type,
        "received_at" => received_at.utc.iso8601(6)
      }.compact.transform_values { |value| value.to_s.dup.force_encoding(Encoding::UTF_8).scrub }

      "#{JSON.generate(metadata)}\n".b + body.b
    end

    # The body as text for the signature check; the bytes are not changed.
    def signed_body
      body.dup.force_encoding(Encoding::UTF_8)
    end

    # What the workflow records as its request: the hook's JSON payload.
    def request
      payload = content_type == FORM_CONTENT_TYPE ? Rack::Utils.parse_query(body)["payload"] : body

      { "hash_id" => hash_id, "payload" => payload.to_s.dup.super_encode_to_utf8 }.compact
    end
  end
end
