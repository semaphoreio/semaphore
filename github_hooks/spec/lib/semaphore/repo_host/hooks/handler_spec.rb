require "spec_helper"

RSpec.describe Semaphore::RepoHost::Hooks::Handler do
  before do
    @logger = ::Logman.new
    @workflow = FactoryBot.create(:workflow)
  end

  describe ".run" do
    before do
      allow(Semaphore::RepoHost::Hooks::Handler).to receive(:delete_branch)
      allow(Semaphore::RepoHost::Hooks::Handler).to receive(:launch_pipeline)
      allow(described_class).to receive(:webhook_signature_valid?).and_return(true)
    end

    context "when request should not be processed" do
      before do
        allow(@workflow.payload).to receive(:includes_ci_skip?).and_return(true)
      end

      it "logs the filtering" do
        expect(@logger).to receive(:info).with("request-is-filtered")

        described_class.run(@workflow, @logger)

        expect(@workflow.reload.state).to eq(Workflow::STATE_SKIP_CI)
      end
    end

    context "when org is restricted for members" do
      let(:repo_host) { double(::RepoHost::Github::Client.new("token")) }

      before do
        project = FactoryBot.create(:project, :for_member_restricted_org)
        @workflow = FactoryBot.create(:workflow, :project => project)

        allow(described_class).to receive(:project_member?).and_return(true)
      end

      it "denies member branch workflow" do
        expect(@logger).to receive(:info).with("member-workflow-denied")
        described_class.run(@workflow, @logger)
        expect(@workflow.reload.state).to eq(Workflow::STATE_MEMBER_DENIED)
      end

      it "denies member tag workflow" do
        allow(@workflow.payload).to receive(:tag?).and_return(true)
        expect(@logger).to receive(:info).with("member-workflow-denied")
        described_class.run(@workflow, @logger)
        expect(@workflow.reload.state).to eq(Workflow::STATE_MEMBER_DENIED)
      end

      it "denies member forked pull request workflow" do
        allow(@workflow).to receive(:payload).and_return(RepoHost::Github::Payload.new(RepoHost::Github::Responses::Payload.post_receive_hook_pull_request))
        allow(@workflow.project).to receive(:build_forked_pr).and_return(true)

        expect(@logger).to receive(:info).with("member-workflow-denied")
        described_class.run(@workflow, @logger)
        expect(@workflow.reload.state).to eq(Workflow::STATE_MEMBER_DENIED)
      end
    end

    context "when org is restricted for non-members" do
      let(:repo_host) { double(::RepoHost::Github::Client.new("token")) }

      before do
        project = FactoryBot.create(:project, :for_non_member_restricted_org)
        @workflow = FactoryBot.create(:workflow, :project => project)

        allow(described_class).to receive(:project_member?).and_return(false)
      end

      it "denies non-member forked pr workflow" do
        allow(@workflow).to receive(:payload).and_return(RepoHost::Github::Payload.new(RepoHost::Github::Responses::Payload.post_receive_hook_pull_request))
        allow(@workflow.project).to receive(:build_forked_pr).and_return(true)

        expect(@logger).to receive(:info).with("non-member-workflow-denied")
        described_class.run(@workflow, @logger)
        expect(@workflow.reload.state).to eq(Workflow::STATE_NON_MEMBER_DENIED)
      end
    end

    context "PR approval" do
      it "marks workflow as pr approval" do
        allow(@workflow.payload).to receive(:pr_approval?).and_return(true)
        expect(@logger).to receive(:info).with("pr-approval")

        described_class.run(@workflow, @logger)

        expect(@workflow.reload.state).to eq(Workflow::STATE_PR_APPROVAL)
      end

      it "launches workflow if marked as allowed user" do
        workflow = FactoryBot.create(
          :workflow,
          :project_id => @workflow.project_id,
          :state => Workflow::STATE_SKIP_FILTERED_CONTRIBUTOR
        )
        workflow.update(:git_ref => "refs/pull/45/merge")

        allow(@workflow.payload).to receive_messages(issue_number: 45, pr_approval?: true)

        expect(described_class).to receive(:launch_pipeline).with(kind_of(Branch), workflow, @logger)

        allow(Semaphore::RepoHost::Hooks::Handler).to receive(:forked_pr_allowed?).and_return(true)

        described_class.run(@workflow, @logger)
      end

      it "does not launch workflow if marked as not allowed user" do
        workflow = FactoryBot.create(
          :workflow,
          :project_id => @workflow.project_id,
          :state => Workflow::STATE_SKIP_FILTERED_CONTRIBUTOR
        )
        workflow.update(:git_ref => "refs/pull/45/merge")

        allow(@workflow.payload).to receive_messages(issue_number: 45, pr_approval?: true)

        expect(described_class).not_to receive(:launch_pipeline)

        allow(Semaphore::RepoHost::Hooks::Handler).to receive(:forked_pr_allowed?).and_return(false)

        described_class.run(@workflow, @logger)
      end
    end

    context "whitelisting" do
      it "skips when tag is not on whitelist" do
        allow(@workflow.payload).to receive(:tag?).and_return(true)
        allow(described_class).to receive(:whitelisted?).and_return(false)
        expect(@logger).to receive(:info).with("tag-not-whitelisted")

        described_class.run(@workflow, @logger)

        expect(@workflow.reload.state).to eq(Workflow::STATE_WHITELIST_TAG)
      end

      it "skips when branch is not on whitelist" do
        allow(described_class).to receive(:whitelisted?).and_return(false)
        expect(@logger).to receive(:info).with("branch-not-whitelisted")

        described_class.run(@workflow, @logger)

        expect(@workflow.reload.state).to eq(Workflow::STATE_WHITELIST_BRANCH)
      end

      it "skips when branch is not on whitelist but it's already created and archived" do
        FactoryBot.create(:branch, :project => @workflow.project, :name => @workflow.payload.branch,
                                   :archived_at => Time.now)

        allow(described_class).to receive(:whitelisted?).and_return(false)
        expect(@logger).to receive(:info).with("branch-not-whitelisted")

        described_class.run(@workflow, @logger)

        expect(@workflow.reload.state).to eq(Workflow::STATE_WHITELIST_BRANCH)
      end

      it "skips when branch is not on whitelist, it's already created and enforce whitelist is turned on on instance" do
        FactoryBot.create(:branch, :project => @workflow.project, :name => @workflow.payload.branch)

        allow(App).to receive(:enforce_whitelist).and_return(true)
        allow(described_class).to receive(:whitelisted?).and_return(false)
        expect(@logger).to receive(:info).with("branch-not-whitelisted")

        described_class.run(@workflow, @logger)

        expect(@workflow.reload.state).to eq(Workflow::STATE_WHITELIST_BRANCH)
      end

      it "skips when branch is not on whitelist, it's already created and enforce whitelist is turned on on organization" do
        FactoryBot.create(:branch, :project => @workflow.project, :name => @workflow.payload.branch)

        allow(App).to receive(:enforce_whitelist).and_return(false)
        allow(described_class).to receive(:whitelisted?).and_return(false)
        expect(@logger).to receive(:info).with("branch-not-whitelisted")

        @workflow.project.organization.update(:settings => { "enforce_whitelist" => "true" })

        described_class.run(@workflow, @logger)

        expect(@workflow.reload.state).to eq(Workflow::STATE_WHITELIST_BRANCH)
      end

      it "continues when branch is not on whitelist, it's already created and enforce whitelist is turned off" do
        FactoryBot.create(:branch, :project => @workflow.project, :name => @workflow.payload.branch)

        allow(described_class).to receive(:whitelisted?).and_return(false)
        expect(@logger).not_to receive(:info).with("branch-not-whitelisted")

        @workflow.project.organization.update(:settings => { "enforce_whitelist" => "false" })

        described_class.run(@workflow, @logger)
      end
    end

    context "when request should be processed" do
      before do
        allow(@workflow.payload).to receive(:includes_ci_skip?).and_return(false)
      end

      context "when the branch was deleted" do
        before do
          allow(@workflow.payload).to receive(:branch_deleted?).and_return(true)
        end

        it "runs the delete branch strategy" do
          expect(described_class).to receive(:delete_branch).with(@workflow, @logger)

          described_class.run(@workflow, @logger)

          expect(@workflow.reload.state).to eq(Workflow::STATE_DELETING_BRANCH)
        end
      end

      context "when a new push was detected" do
        it "runs the launch build strategy" do
          expect(described_class).to receive(:launch_pipeline)

          described_class.run(@workflow, @logger)
        end
      end

      context "when workflow is a forked pull request" do
        let(:repo_host) { double(::RepoHost::Github::Client.new("token")) }

        before do
          allow(@workflow).to receive(:payload).and_return(RepoHost::Github::Payload.new(RepoHost::Github::Responses::Payload.post_receive_hook_pull_request))
          allow(@workflow.project).to receive(:build_forked_pr).and_return(true)
          allow(::RepoHost::Factory).to receive(:create_from_project).and_return(repo_host)
        end

        context "and we are not building forked prs" do
          before do
            allow(@workflow.project).to receive(:build_forked_pr).and_return(false)
          end

          it "logs the skip info" do
            expect(@logger).to receive(:info).with("skip-forked-prs")

            described_class.run(@workflow, @logger)

            expect(@workflow.reload.state).to eq(Workflow::STATE_SKIP_FORKED_PR)
          end
        end

        context "and we are not allowing this contributor" do
          before do
            allow(@workflow.project).to receive(:allowed_contributors).and_return("radwo")
          end

          it "logs the skip info" do
            expect(@logger).to receive(:info).with("skip-filtered-contributor")

            described_class.run(@workflow, @logger)

            expect(@workflow.reload.state).to eq(Workflow::STATE_SKIP_FILTERED_CONTRIBUTOR)
          end
        end

        context "and the merge commit is mergeable" do
          before do
            allow(repo_host).to receive(:validate_token_presence!)
            allow(repo_host).to receive(:pull_request).and_return(:merge_commit_sha => "foo", :mergeable => true)
          end

          it "creates ref on github" do
            allow(repo_host).to receive(:reference).with("renderedtext/plakatt",
                                                         "semaphoreci/foo").and_raise(::RepoHost::RemoteException::NotFound)

            allow(repo_host).to receive(:create_ref).with("renderedtext/plakatt", "refs/semaphoreci/foo", "foo")

            allow(repo_host).to receive(:commit).with("renderedtext/plakatt",
                                                      "97114836a47ff614e70e863df819f908877ee1c9").and_return(RepoHost::Github::Responses::Commit.commit)

            expect(described_class.run(@workflow, @logger)).to be_nil
          end
        end

        context "and the merge commit is not mergeable" do
          before do
            allow(repo_host).to receive(:validate_token_presence!)
            allow(repo_host).to receive(:pull_request).and_return(:merge_commit_sha => "", :mergeable => false)
          end

          it "logs the non mergeable pr" do
            expect(@logger).to receive(:info).with("pr-non-mergeable")

            described_class.run(@workflow, @logger)

            expect(@workflow.reload.state).to eq(Workflow::STATE_PR_NON_MERGEABLE)
          end
        end

        context "and the pull-request is not found" do
          before do
            allow(repo_host).to receive(:validate_token_presence!)
            allow(repo_host).to receive(:pull_request).and_raise(::RepoHost::RemoteException::NotFound,
                                                                 "Not Found Message")
          end

          it "logs the not found pr" do
            expect(@logger).to receive(:info).with("pr-not-found Not Found Message")

            described_class.run(@workflow, @logger)

            expect(@workflow.reload.state).to eq(Workflow::STATE_PR_NOT_FOUND)
          end
        end

        context "and the pull-request get throws unknown error" do
          before do
            allow(repo_host).to receive(:validate_token_presence!)
            allow(repo_host).to receive(:pull_request).and_raise(::RepoHost::RemoteException::Unknown,
                                                                 "Oops")
          end

          it "logs the error and raises again" do
            expect(@logger).to receive(:error).with("Unknown error", error: "Oops")

            expect(described_class.run(@workflow, @logger)).to raise_error("Oops")
          end
        end

        context "and the pull-request is eventually found, but non mergeable" do
          before do
            allow(repo_host).to receive(:validate_token_presence!)
            allow(repo_host).to receive(:pull_request).and_return({ :merge_commit_sha => "", :mergeable => false })
          end

          it "logs the non mergeable pr" do
            expect(@logger).to receive(:info).with("pr-non-mergeable")

            described_class.run(@workflow, @logger)

            expect(@workflow.reload.state).to eq(Workflow::STATE_PR_NON_MERGEABLE)
          end
        end

        context "and there is a problem with fetching mergeable status" do
          before do
            allow(repo_host).to receive(:validate_token_presence!)
            allow(repo_host).to receive(:pull_request).and_return(:merge_commit_sha => "", :mergeable => nil)
          end

          it "logs the non mergeable pr" do
            expect(@logger).to receive(:info).with("pr-non-mergeable")

            described_class.run(@workflow, @logger)

            expect(@workflow.reload.state).to eq(Workflow::STATE_PR_NON_MERGEABLE)
          end
        end
      end
    end
  end

  describe ".delete_branch" do
    context "when the branch exists and plumber response with OK" do
      it "deletes the branch" do
        expect_any_instance_of(InternalApi::Plumber::Admin::Stub).to receive(:terminate_all).and_return(
          InternalApi::Plumber::TerminateAllResponse.new(
            :response_status => InternalApi::Plumber::ResponseStatus.new(
              :code => InternalApi::Plumber::ResponseStatus::ResponseCode::OK
            )
          )
        )

        branch = FactoryBot.create(:branch, :project => @workflow.project, :name => @workflow.payload.branch)

        expect do
          described_class.delete_branch(@workflow, @logger)
        end.to change {
          Branch.not_archived.find_by(:id => branch.id)
        }.from(an_instance_of(Branch)).to(nil)
      end
    end

    context "when the branch exists and plumber response with BAD_PARAM" do
      it "deletes the branch" do
        expect_any_instance_of(InternalApi::Plumber::Admin::Stub).to receive(:terminate_all).and_return(
          InternalApi::Plumber::TerminateAllResponse.new(
            :response_status => InternalApi::Plumber::ResponseStatus.new(
              :code => InternalApi::Plumber::ResponseStatus::ResponseCode::BAD_PARAM
            )
          )
        )

        branch = FactoryBot.create(:branch, :project => @workflow.project, :name => @workflow.payload.branch)

        expect do
          described_class.delete_branch(@workflow, @logger)
        end.to change {
          Branch.not_archived.find_by(:id => branch.id)
        }.from(an_instance_of(Branch)).to(nil)
      end
    end

    context "when the branch does not exist" do
      it "logs that the branch does not exists" do
        expect(@logger).to receive(:info).with("skipping-branch-delete", :reason => "Branch does not exists")

        described_class.delete_branch(@workflow, @logger)
      end
    end
  end

  describe ".find_or_create_branch" do
    context "when a branch does not exists" do
      it "creates a branch" do
        expect do
          described_class.find_or_create_branch(@workflow, @logger)
        end.to change {
          @workflow.project.branches.where(:name => @workflow.payload.branch).exists?
        }.from(false).to(true)
      end
    end

    context "when a branch already exists" do
      before do
        @branch = FactoryBot.create(:branch, :project => @workflow.project, :name => @workflow.payload.branch)
      end

      it "returns the existsing branch" do
        expect(described_class.find_or_create_branch(@workflow, @logger)).to eq(@branch)
      end
    end
  end

  describe ".launch_pipeline" do
    before do
      @user = FactoryBot.create(:user, :github_connection)
      @project = FactoryBot.create(:project, :creator => @user)
      @branch = FactoryBot.create(:branch, :project => @project)

      request = { :payload => RepoHost::Github::Responses::Payload.post_receive_hook }.with_indifferent_access

      @workflow = FactoryBot.create(:workflow, :request => request)
    end

    context "when request is comming from github app push" do
      before do
        @user = FactoryBot.create(:user_darkofabijan, :github_connection)
        @project = FactoryBot.create(:project, :creator => @user)
        @branch = FactoryBot.create(:branch, :project => @project)

        request = { :payload => RepoHost::Github::Responses::Payload.github_app_push_as_bot }.with_indifferent_access

        @workflow = FactoryBot.create(:workflow, :request => request)
      end

      it "returns correct id of the requester" do
        expect(described_class.requester_id(@workflow)).to eq(@user.id)
      end
    end

    context "when Plumber responds with OK" do
      it "returns status :OK" do
        expect_any_instance_of(InternalApi::PlumberWF::WorkflowService::Stub).to receive(:schedule).and_return(
          InternalApi::PlumberWF::ScheduleResponse.new(
            :status => InternalApi::Status.new(:code => Google::Rpc::Code::OK),
            :wf_id => "1",
            :ppl_id => "7054527d-21ff-4424-877f-f0c20e51c025"
          )
        )

        state = described_class.launch_pipeline(@branch, @workflow, Rails.logger)

        expect(state).to eq({
                              :code => :OK,
                              :ppl_id => "7054527d-21ff-4424-877f-f0c20e51c025",
                              :wf_id => "1"
                            })
        expect(@workflow.reload.ppl_id).to eq("7054527d-21ff-4424-877f-f0c20e51c025")
      end
    end

    context "when the Plumber responds with the NOT_FOUND code" do
      it "tries to send schedule request but raises an error" do
        expect_any_instance_of(InternalApi::PlumberWF::WorkflowService::Stub).to receive(:schedule).and_return(
          InternalApi::PlumberWF::ScheduleResponse.new(
            :status => InternalApi::Status.new(:code => Google::Rpc::Code::NOT_FOUND,
                                               :message => "Something went wrong"),
            :wf_id => "1"
          )
        )

        expect do
          described_class.launch_pipeline(@branch, @workflow,
                                          Rails.logger)
        end.to raise_error('The Plumber returned <InternalApi::Status: code: :NOT_FOUND, message: "Something went wrong">')
      end
    end
  end

  describe ".whitelisted?" do
    it "returns true if whitelist is empty" do
      ref = "foo"
      whitelist = []

      expect(described_class.whitelisted?(ref, whitelist, @logger)).to be(true)
    end

    it "returns false if ref is not whitelisted" do
      ref = "foo"
      whitelist = %w[bar baz]

      expect(described_class.whitelisted?(ref, whitelist, @logger)).to be(false)
    end

    it "returns true if ref is on whitelist" do
      ref = "foo"
      whitelist = ["foo"]

      expect(described_class.whitelisted?(ref, whitelist, @logger)).to be(true)
    end

    it "returns true if ref mach pattern from whitelist" do
      ref = "foo"
      whitelist = ["/fo/"]

      expect(described_class.whitelisted?(ref, whitelist, @logger)).to be(true)
    end

    it "returns false if regexp is invalid" do
      ref = "foo"
      whitelist = ["/*/"]

      expect(described_class.whitelisted?(ref, whitelist, @logger)).to be(false)
    end
  end
end
