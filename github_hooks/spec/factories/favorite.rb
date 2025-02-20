FactoryBot.define do
  factory :favorite do
    user
    sequence(:organization_id) { |n| "#{n}195f081-0516-4e8b-bdae-9500a4d80bff" }
    sequence(:favorite_id) { |n| "#{n}bb2c8a5-74f5-4a13-8044-b8e257fb3d5a" }
    kind { "project" }
  end
end
