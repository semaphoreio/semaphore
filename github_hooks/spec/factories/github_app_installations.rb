FactoryBot.define do
  factory :github_app_installation do
    installation_id { 13609976 }
    repositories do
      ["renderedtext/guard", "semaphoreio/semaphore"]
    end

    after(:create) do |installation|
      repositories = Array(installation[:repositories]).map do |slug|
        { "id" => 0, "slug" => slug }
      end
      installation.replace_repositories!(repositories)
    end
  end
end
