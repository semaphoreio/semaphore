FactoryBot.define do
  factory :user, :aliases => [:subscriber] do
    sequence(:email) { |n| "marvin#{n}@renderedtext.com" }
    sequence(:name) { |n| "marvin#{n}" }
    created_at { DateTime.now }
    visited_at { DateTime.now }
    time_zone { "UTC" }
    company { "Apple" }

    trait :with_referer do
      after(:create) do |user|
        user.create_referer!(:entry_url => "entry_url", :http_referer => "referer")
      end
    end

    trait :github_connection do
      after(:create) do |user|
        user.repo_host_accounts << FactoryBot.create(:github_account, :user => user)
      end
    end

    trait :bitbucket_connection do
      after(:create) do |user|
        user.repo_host_accounts << FactoryBot.create(:bitbucket_account, :user => user)
      end
    end

    trait :with_public_ssh_key do
      after(:create) do |user|
        user.public_ssh_keys << FactoryBot.create(:public_ssh_key)
      end
    end

    trait :signup_with_github do
      signup_method { "from_github" }
    end

    trait :signup_with_semaphore do
      signup_method { "from_semaphore" }
    end

    trait :flagged_as_miner do
      flagged_as_miner { true }
      blocked_at { Time.now }
    end
  end

  factory :user_marvinwills, :parent => :user do
    email { "marvin@renderedtext.com" }

    trait :github_connection do
      after(:create) do |user|
        user.repo_host_accounts << FactoryBot.create(:github_account_marvin)
      end
    end

    trait :bitbucket_connection do
      after(:create) do |user|
        user.repo_host_accounts << FactoryBot.create(:bitbucket_account_marvin)
      end
    end
  end

  factory :user_darkofabijan, :parent => :user do
    email { "darko@renderedtext.com" }

    trait :github_connection do
      after(:create) do |user|
        user.repo_host_accounts << FactoryBot.create(:repo_host_account_darko)
      end
    end
  end

  factory :user_vlasar, :parent => :user do
    email { "vladimir@vladimirsaric.com" }

    trait :github_connection do
      after(:create) do |user|
        user.repo_host_accounts << FactoryBot.create(:repo_host_account_vlasar)
      end
    end
  end
end
