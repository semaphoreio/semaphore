module RepoHost::Responses::Format
  class Hook
    def initialize(hook_hash)
      @id = hook_hash["id"]
    end

    def to_h
      { "id" => @id }
    end
  end
end
