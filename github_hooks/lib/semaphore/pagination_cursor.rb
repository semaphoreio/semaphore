module Semaphore
  class PaginationCursor
    class InvalidCursor < StandardError; end

    # Semaphore::PaginationCursor is used to transalte cursor token into valid
    # sql condition.
    # This class checks if page_token is valid, translates this token into
    # condition and sort string. It also generates next_page_token to be used
    # in next request.
    #
    # Usage:
    #
    # c = Semaphore::PaginationCursor.new(page_token, params)
    # c.validate! # throws Semaphore::PaginationCursor::InvalidCursor
    # scope = User.all # scope that we are using
    # scope = scope.where(c.condition).order(c.sort_string) # here we are injecting token based condition and sorting string
    # collection = scope.limit(size).to_a
    # next_page_token = c.next_page_token(collection.last, scope.last)
    #
    # page_token - from last request, should be empty for first page
    # params - parameters used in scope, to ensure that page_token is used in proper search
    # Required keys in params:
    #     id_field - name of id field
    #     field    - name of sorting field (eg. created_at for default sort)
    #     order    - sorting direction (asc/desc)

    def initialize(token, params)
      @token = token
      @params = params
    end

    def valid?
      validate!
      true
    rescue Semaphore::PaginationCursor::InvalidCursor
      false
    end

    def validate!
      unless token.empty? || params_digest == token_digest
        raise_invalid_token
      end
    end

    def condition
      if token.empty?
        "1=1"
      else
        "(#{field} #{sign} '#{value}') OR (#{field} = '#{value}' AND #{id_field} #{sign} '#{id_value}')"
      end
    end

    def sort_string
      "#{field} #{order}, #{id_field} #{order}"
    end

    def next_page_token(last_element, last_in_scope)
      if last_element == last_in_scope
        ""
      else
        Base64.urlsafe_encode64({
          "id_value" => last_element.id,
          "value" => last_element.send(:"#{field.split(".").last}_before_type_cast"),
          "digest" => params_digest
        }.to_json)
      end
    end

    private

    attr_reader :token, :params

    def params_digest
      Digest::MD5.hexdigest(params.to_json)
    end

    def token_digest
      token_params.fetch(:digest)
    end

    def value
      token_params.fetch(:value)
    end

    def id_value
      token_params.fetch(:id_value)
    end

    def id_field
      params.fetch(:id_field)
    end

    def field
      params.fetch(:field)
    end

    def order
      params.fetch(:order)
    end

    def sign
      order == "asc" ? ">" : "<"
    end

    def token_params
      @token_params ||= JSON.parse(Base64.urlsafe_decode64(token)).symbolize_keys
    rescue ArgumentError, JSON::ParserError
      raise_invalid_token
    end

    def raise_invalid_token
      raise InvalidCursor.new("This token is invalid: #{token}")
    end
  end
end
