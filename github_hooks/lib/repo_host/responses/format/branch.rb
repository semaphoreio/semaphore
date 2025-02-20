module RepoHost::Responses::Format
  class Branch
    def initialize(branch_hash)
      @name = branch_hash["name"]
    end

    def to_h
      { "name" => @name }
    end
  end
end
