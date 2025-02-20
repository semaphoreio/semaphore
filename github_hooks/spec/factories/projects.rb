# frozen_string_literal: true

FactoryBot.define do
  factory :project do
    cache_id { SecureRandom.uuid }
    sequence(:name) { |n| "plakatt#{n}" }
    organization
    association :creator, :factory => :user
    repository
    description { "The best project" }
    custom_permissions { true }
    debug_empty { true }
    debug_pr { true }
    attach_forked_pr { true }

    after(:stub) do |project|
      project.slug = project.name
    end

    after(:create) do |project|
      creator = project.creator

      if repo_host_account = creator.repo_host_account(:github)
        project.repository.update(:owner => repo_host_account.login)
      end
    end

    trait :random_name do
      sequence(:name) { |n| "project-#{n}" }
    end

    trait :for_member_restricted_org do
      after(:create) do |project|
        project.organization.update(:deny_member_workflows => true)
      end
    end

    trait :for_non_member_restricted_org do
      after(:create) do |project|
        project.organization.update(:deny_non_member_workflows => true)
      end
    end

    trait :with_private_repository do
      association :repository, :factory => :private_repository
    end

    trait :with_public_repository do
      association :repository, :factory => :public_repository
    end

    trait :with_long_build do
      after(:create) do |project|
        branch = FactoryBot.create(:branch, :project => project)
        build = FactoryBot.create(:build, :passed, :branch => branch)

        build.jobs.each { |j| j.update_attribute(:started_at, 2.hours.ago) }
      end
    end
  end

  factory :project_with_branch, :parent => :project do
    after(:create) do |project|
      FactoryBot.create(:branch, :project => project)
    end
  end

  factory :github_project, :parent => :project do
    after(:create) do |project|
      project.repository.update!(:provider => Repository::GITHUB_PROVIDER)
    end
  end

  factory :bitbucket_project, :parent => :project do
    after(:create) do |project|
      project.repository.update!(:provider => Repository::BITBUCKET_PROVIDER)
    end
  end
end
