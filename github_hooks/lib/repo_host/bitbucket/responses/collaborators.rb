module RepoHost::Bitbucket::Responses
  class Collaborators
    def self.parse(response)
      members = []
      added_usernames = []

      response.each do |group|
        group["group"]["members"].each do |member|
          unless added_usernames.include?(member["username"])
            members << format_member(member)
            added_usernames << member["username"]
          end
        end
      end

      members
    end

    private

    def self.format_member(member)
      collaborator_hash = { "id" => member["username"], "login" => member["username"], "name" => member["username"], "avatar" => member["avatar"] }

      RepoHost::Responses::Format::Collaborator.new(collaborator_hash).to_h
    end
  end
end
