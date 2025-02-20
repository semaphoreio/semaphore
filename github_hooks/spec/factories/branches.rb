FactoryBot.define do
  factory :branch do
    name { "master" }
    project

    trait(:random_name) do
      sequence(:name) { |n| "feature-#{n}" }
    end

    factory :branch_without_project do
      after(:create) do |branch, _evaluator|
        branch.project.delete
      end
    end
  end
end
