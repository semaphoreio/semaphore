FactoryBot.define do
  factory :organization_contact do
    organization
    contact_type { "COTACT_TYPE_SECURITY" }
  end
end
