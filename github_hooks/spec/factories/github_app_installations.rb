FactoryBot.define do
  factory :github_app_installation do
    installation_id { 13609976 }
    repositories do
      ["renderedtext/guard", "semaphoreio/semaphore"]
    end

    after(:create) do |installation|
      installation.replace_repositories!(Array(installation[:repositories]))
    end
  end
end
