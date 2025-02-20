FactoryBot.define do
  factory :member do
    organization
    sequence(:github_uid) { |n| "123#{n}".to_i }
    github_username { "radwo" }
    repo_host { "github" }
    repo_host_account
  end
end
