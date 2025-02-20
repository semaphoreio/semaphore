# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :repo_host_account do
    token { "63146da137f3612fd419f81fac818cd05b1c8bba" }
    sequence(:github_uid) { |n| "1234#{n}".to_i }
    sequence(:login) { |n| "repo_host_#{n}" }
    name { "MyString" }
    permission_scope { "MyString" }
    repo_host { Repository::DEFAULT_PROVIDER }
    user
    revoked { false }
  end

  factory :github_account, :parent => :repo_host_account do
    repo_host { Repository::GITHUB_PROVIDER }
  end

  factory :bitbucket_account, :parent => :repo_host_account do
    repo_host { Repository::BITBUCKET_PROVIDER }
    refresh_token { "5982288da80e9eb441261e2deab205056095ba4d" }
  end

  factory :github_account_marvin, :parent => :repo_host_account do
    token { "eaab779bafe8953045b6e143ddb9c68c2da001ca" }
    login { "marvinwills" }
    github_uid { 9428420 }
    repo_host { Repository::GITHUB_PROVIDER }
    permission_scope { "repo" }
  end

  factory :github_account_marvin_solo, :parent => :repo_host_account do
    token { "59322e8dc80e9eb441261e2deab205056095ba4d" }
    login { "marvinwills-solo" }
    github_uid { 12080247 }
    repo_host { Repository::GITHUB_PROVIDER }
    permission_scope { "public_repo" }
  end

  factory :bitbucket_account_marvin, :parent => :repo_host_account do
    login { "" }
    github_uid { "marvinwills" }
    repo_host { Repository::BITBUCKET_PROVIDER }
    token { "L7FkEbampn7dmsbWB2" }
    secret { "Ap2H3Fc9ME9JdnwWzqWQqMSRWgpMFZRJ" }
    permission_scope { "repo" }
  end

  factory :repo_host_account_darko, :parent => :repo_host_account do
    token { "79a14ef8ac1042839a98a56db93dbca356a850ae" }
    login { "darkofabijan" }
    github_uid { 20469 }
    repo_host { Repository::GITHUB_PROVIDER }
    permission_scope { "repo" }
  end

  factory :repo_host_account_vlasar, :parent => :repo_host_account do
    login { "vlasar" }
    github_uid { 220781 }
    repo_host { Repository::GITHUB_PROVIDER }
    permission_scope { "repo" }
  end
end
