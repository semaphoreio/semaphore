FactoryBot.define do
  factory :oauth_connection do
    provider { "github" }
    sequence(:github_uid) { |n| "uid-#{n}" }
    token { "123456" }
    user
  end
end
