module RepoHost::Bitbucket::Responses
  class Hooks
    def self.parse_hook(response)
      hook_hash = { "id" => response["uuid"] }

      RepoHost::Responses::Format::Hook.new(hook_hash).to_h
    end
  end
end
