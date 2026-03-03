class Avatar
  GENERIC_AVATAR_URL = "https://avatars2.githubusercontent.com/u/0?s=460&v=4".freeze

  def self.avatar_url(github_uid)
    if github_uid.nil? || github_uid.to_s.start_with?("user_", "service_account_")
      GENERIC_AVATAR_URL
    else
      "https://avatars2.githubusercontent.com/u/#{github_uid}?s=460&v=4"
    end
  end
end
