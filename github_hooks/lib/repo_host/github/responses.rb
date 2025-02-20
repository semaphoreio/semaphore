module RepoHost::Github
  module Responses

    def self.invalid_json
      '{"message":"Problems parsing JSON"}'
    end

    def self.wrong_values
      '{"message":"Body should be a JSON Hash"}'
    end

    def self.validation_error
      '{
       "message": "Validation Failed",
       "errors": [
         {
           "resource": "Issue",
           "field": "title",
           "code": "missing_field"
         }
       ]
     }'
    end

    def self.hook_not_found
      '{"message":"Not Found"}'
    end

  end
end
