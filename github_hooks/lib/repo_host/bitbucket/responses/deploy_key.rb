module RepoHost::Bitbucket::Responses
  class DeployKey
    def self.parse(response)
      deploy_key_hash = { "id" => response["pk"] }

      RepoHost::Responses::Format::DeployKey.new(deploy_key_hash).to_h
    end
  end
end
