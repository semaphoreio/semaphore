FactoryBot.define do
  factory :workflow do
    project

    # NOTE: In production, we are saving and serializing this field as
    # ActionController::Parameters. This, when serialized, allows access with
    # both symbols and string.
    #
    # Changed the class from pure Hash to ActionController::Parameters
    # to match the behaviour seen in production.
    request do
      ActionController::Parameters.new("payload" => File.read(Rails.root.join("fixtures/github_payloads/many_commits.json").to_s))
    end

    after(:create) do |workflow, _evaluator|
      Semaphore::RepoHost::Hooks::Recorder.set_commit_sha(workflow)
      Semaphore::RepoHost::Hooks::Recorder.set_git_ref(workflow)
    end

    factory :workflow_with_branch do
      after(:create) do |workflow, _evaluator|
        if workflow.project
          branch = workflow.project.branches.create(:name => workflow.payload.branch)
          workflow.update_attribute(:branch_id, branch.id)
        end
      end
    end

    trait :for_bitbucket do
      provider { "bitbucket" }
      request { JSON.parse(File.read(Rails.root.join("fixtures/bitbucket_payloads/push_commit_empty_payload.json").to_s)) }
    end
  end
end
