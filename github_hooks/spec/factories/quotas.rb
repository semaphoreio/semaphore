FactoryBot.define do
  factory :quota do
    organization
    type { "MAX_PARALELLISM_IN_ORG" }
    value { 50 }
  end
end
