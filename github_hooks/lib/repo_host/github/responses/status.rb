module RepoHost::Github::Responses::Status

  def self.post_finished_response
    { "target_url" => "https://semaphoreapp.com/projects/1/branches/4470/builds/1", "created_at" => "2012-09-04T16:59:43Z", "description" => "null", "updated_at" => "2012-09-04T16:59:43Z", "url" => "https://api.github.com/repos/renderedtext/semaphore/statuses/219663", "creator" => { "avatar_url" => "https://secure.gravatar.com/avatar/de0d1646d55af6c360ef647bc3b13b7b?d=https://a248.e.akamai.net/assets.github.com%2Fimages%2Fgravatars%2Fgravatar-user-420.png", "login" => "darkofabijan", "url" => "https://api.github.com/users/darkofabijan", "gravatar_id" => "de0d1646d55af6c360ef647bc3b13b7b", "id" => 20469 }, "id" => 219663, "state" => "success" }.to_json
  end

end
