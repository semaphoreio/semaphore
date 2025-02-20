module RepoHost::Bitbucket::Responses
  class Users
    def self.parse_single_user(response)
      user_hash = { "id" => response["user"]["username"],
                    "name" => response["user"]["username"],
                    "email" => "",
                    "avatar_url" => response["user"]["avatar"] }

      RepoHost::Responses::Format::User.new(user_hash).to_h
    end
  end
end
