FactoryBot.define do
  factory :github_app_installation do
    installation_id { 13609976 }
    repositories do
      [
        { "id" => 137368312, "slug" => "renderedtext/guard" },
        { "id" => 217099396, "slug" => "semaphoreio/semaphore" }
      ]
    end
  end
end
