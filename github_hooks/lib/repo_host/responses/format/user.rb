module RepoHost::Responses::Format
  class User
    def initialize(user_hash)
      @id = user_hash["id"]
      @name = user_hash["name"]
      @email = user_hash["email"]
      @avatar_url = user_hash["avatar_url"]
    end

    def to_h
      { "id" => @id, "name" => @name, "email" => @email, "avatar_url" => @avatar_url }
    end
  end
end
