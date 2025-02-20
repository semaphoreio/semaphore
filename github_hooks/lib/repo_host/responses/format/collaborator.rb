module RepoHost::Responses::Format
  class Collaborator
    def initialize(collaborator_hash)
      @id = collaborator_hash["id"]
      @login = collaborator_hash["login"]
      @name = collaborator_hash["name"]
      @avatar = collaborator_hash["avatar"]
    end

    def to_h
      { "id" => @id, "login" => @login, "name" => @name, "avatar" => @avatar }
    end
  end
end
