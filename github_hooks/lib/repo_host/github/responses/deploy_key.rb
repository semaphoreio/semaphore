module RepoHost::Github::Responses::DeployKey

  def self.post_key
    '{
      "url": "https://api.github.com/user/keys/1",
      "id":"1",
      "title": "octocat@octomac",
      "key": "ssh-rsa AAA..."
      }'
  end

end
