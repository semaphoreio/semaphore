FactoryBot.define do
  factory :github_app_installation do
    installation_id { 13609976 }
    repositories { ["renderedtext/guard", "semaphoreio/semaphore"] }
  end
end
