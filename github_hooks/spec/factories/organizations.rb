FactoryBot.define do
  factory :organization do
    sequence(:name)     { |n| "Organization #{n}" }
    sequence(:username) { |n| "organization-#{n}" }
    association :creator, :factory => [:user, :github_connection]
  end
end
