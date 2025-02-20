FactoryBot.define do
  factory :repository do
    owner { "renderedtext" }
    name { "plakatt" }
    url { "git://github.com/renderedtext/plakatt.git" }
    private { true }
    provider { Repository::DEFAULT_PROVIDER }
  end

  factory :private_repository, :parent => :repository do
    private { true }
  end

  factory :public_repository, :parent => :repository do
    private { false }
  end
end
