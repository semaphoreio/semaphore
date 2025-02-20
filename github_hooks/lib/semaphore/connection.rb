module Semaphore

  class Connection

    REQUEST_ID_LENGTH = 6
    DEFAULT_RETRY_EXCEPTIONS = [Errno::ETIMEDOUT, "Timeout::Error", "Error::TimeoutError"]
    ADDITIONAL_RETRY_EXCEPTIONS = [Faraday::ConnectionFailed]
    RETRY_EXCEPTIONS = DEFAULT_RETRY_EXCEPTIONS + ADDITIONAL_RETRY_EXCEPTIONS

    TEN_MINUTES = 600

    def initialize(url)
      @url = url
    end

    def post(path, body)
      log("post", path, body) do
        connection.post do |request|
          request.url path
          request.headers["Content-Type"] = "application/json"
          request.body = body
          request.options.timeout = TEN_MINUTES
        end
      end
    end

    def get(path, params)
      log("get", path, params) do
        connection.get do |request|
          request.url path, params
        end
      end
    end

    def patch(path, body)
      log("patch", path, body) do
        connection.patch do |request|
          request.url path
          request.body = body
          request.options.timeout = TEN_MINUTES
        end
      end
    end

    def put(path, body)
      log("put", path, body) do
        connection.put do |request|
          request.url path
          request.body = body
          request.options.timeout = TEN_MINUTES
        end
      end
    end

    def delete(path, body)
      log("delete", path, body) do
        connection.delete do |request|
          request.url path
          request.body = body
          request.options.timeout = TEN_MINUTES
        end
      end
    end

    private

    def connection
      Faraday.new(:url => @url) do |builder|
        builder.request :retry, :max => 10, :interval => 1, :backoff_factor => 2, :exceptions => RETRY_EXCEPTIONS
        builder.request :json
        builder.adapter :net_http
      end
    end

    def log(method, path, body)
      request_id = SecureRandom.urlsafe_base64(REQUEST_ID_LENGTH)
      logger = Rails.logger

      report = {
        :message => "start",
        :id => request_id,
        :url => @url,
        :path => path,
        :method => method,
        :body => body
      }

      logger.info(report.inspect)

      response = yield

      done_report = report.merge(:message => "done",
                                 :id => request_id,
                                 :response_body => response.body)

      logger.info(done_report.inspect)

      response
    end
  end

end
