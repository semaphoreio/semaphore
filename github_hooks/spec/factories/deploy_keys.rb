FactoryBot.define do
  factory :deploy_key do
    private_key { "private_key" }
    public_key { "public_key" }
    project
  end
end
