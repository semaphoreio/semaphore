module RepoHost::Responses::Format
  class DeployKey
    def initialize(deploy_key_hash)
      @id = deploy_key_hash["id"]
    end

    def to_h
      { "id" => @id }
    end
  end
end
