FactoryBot.define do
  factory :github_app_installation do
    installation_id { 13609976 }
    repositories do
      ["renderedtext/guard", "semaphoreio/semaphore"]
    end

    after(:create) do |installation|
      repositories = Array(installation[:repositories]).filter_map do |repository|
        case repository
        when Hash
          slug = repository["slug"] || repository[:slug]
          next if slug.blank?

          id = repository["id"] || repository[:id] || 0
          { "id" => id.to_i, "slug" => slug }
        else
          slug = repository.to_s
          next if slug.blank?

          { "id" => 0, "slug" => slug }
        end
      end
      installation.replace_repositories!(repositories)
    end
  end
end
