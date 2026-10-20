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
      before do
        allow(Semaphore::FeatureFlags).to receive(:enabled?).with(:sem_approve_options, anything).and_return(true)
      end

      # Fixed timeline used by the approval tests. In the normal case a blocked
      # forked-PR workflow is created *before* the maintainer's approval comment
      # (the PR event arrives, is blocked, then a maintainer comments). Tests
      # that model a contributor pushing after approval create a workflow at
      # `after_comment`.
      def approval_comment_time
        "2026-07-20T00:00:00Z"
      end

      def before_comment
        Time.utc(2026, 7, 19)
      end

      def after_comment
        Time.utc(2026, 7, 21)
      end

      # A blocked forked-PR workflow whose payload is a real pull_request
      # event, so the shared pull_request? launch path — and the SHA-binding
      # guard — is exercised end to end.
      def build_blocked_pr_workflow(project_id:, pr_number: 1, created_at: before_comment)
        wf = FactoryBot.create(
          :workflow,
          :project_id => project_id,
          :state => Workflow::STATE_SKIP_FILTERED_CONTRIBUTOR,
          :request => ActionController::Parameters.new(
            "payload" => RepoHost::Github::Responses::Payload.post_receive_hook_pull_request
          )
        )
        wf.update(:git_ref => "refs/pull/#{pr_number}/merge", :created_at => created_at)
        wf
      end

      # update_pr_data result whose live head is `head_sha`. Defaults to the
      # approved head, i.e. the approval is still valid (no injected commit).
      def ok_pr_data(workflow, head_sha: nil)
        [
          :ok,
          {
            :mergeable => true,
            :commit_author => "octocat",
            :merge_commit_sha => workflow.commit_sha,
            :ref => workflow.git_ref,
            :head_sha => head_sha || workflow.commit_sha
          },
          nil
        ]
      end

      it "marks the comment workflow as pr approval" do
        allow(@logger).to receive(:info)
        allow(@workflow.payload).to receive(:pr_approval?).and_return(true)
        allow(described_class).to receive(:can_approve_forked_pr?).and_return(false)

        expect(@logger).to receive(:info).with("pr-approval")

        described_class.run(@workflow, @logger)

        expect(@workflow.reload.state).to eq(Workflow::STATE_PR_APPROVAL)
      end

      it "denies approval and does not launch when the requestor lacks the required permission" do
        build_blocked_pr_workflow(project_id: @workflow.project_id, pr_number: 45)

        allow(@logger).to receive(:info)
        allow(Watchman).to receive(:increment)
        allow(@workflow.payload).to receive_messages(issue_number: 45, pr_approval?: true, comment_author: "octocat")
        allow(described_class).to receive(:can_approve_forked_pr?).and_return(false)

        expect(@logger).to receive(:info).with("pr-approval-denied", :requestor => "octocat", :required_permission => "project.view")
        expect(Watchman).to receive(:increment).with("hooks.pr_approval.denied")
        expect(described_class).not_to receive(:launch_pipeline)

        described_class.run(@workflow, @logger)
      end

      it "launches the blocked workflow when the requestor can approve" do
        workflow = FactoryBot.create(
          :workflow,
          :project_id => @workflow.project_id,
          :state => Workflow::STATE_SKIP_FILTERED_CONTRIBUTOR
        )
        workflow.update(:git_ref => "refs/pull/45/merge", :created_at => before_comment)

        allow(@workflow.payload).to receive_messages(issue_number: 45, pr_approval?: true, comment_author: "maintainer", comment_created_at: approval_comment_time)
        allow(described_class).to receive(:can_approve_forked_pr?).and_return(true)

        expect(described_class).to receive(:launch_pipeline).with(kind_of(Branch), workflow, @logger)

        described_class.run(@workflow, @logger)
      end

      it "authorizes the permission check by the commenter's immutable uid" do
        build_blocked_pr_workflow(project_id: @workflow.project_id, pr_number: 45)

        allow(@workflow.payload).to receive_messages(issue_number: 45, pr_approval?: true, comment_author: "maintainer", comment_author_uid: 4242, comment_created_at: approval_comment_time)

        expect(described_class).to receive(:can_approve_forked_pr?)
          .with(@workflow.project, 4242, @logger, :permission => "project.view")
          .and_return(false)

        described_class.run(@workflow, @logger)
      end

      it "requires project.job.rerun when the approval requests an option" do
        build_blocked_pr_workflow(project_id: @workflow.project_id, pr_number: 45)

        allow(@workflow.payload).to receive_messages(issue_number: 45, pr_approval?: true, pr_approval_enable_cache?: true, comment_author: "maintainer", comment_author_uid: 4242, comment_created_at: approval_comment_time)

        expect(described_class).to receive(:can_approve_forked_pr?)
          .with(@workflow.project, 4242, @logger, :permission => "project.job.rerun")
          .and_return(false)
        expect(described_class).not_to receive(:launch_pipeline)

        described_class.run(@workflow, @logger)
      end

      it "does not launch when there is no blocked workflow" do
        allow(@workflow.payload).to receive_messages(issue_number: 999, pr_approval?: true, comment_author: "maintainer", comment_created_at: approval_comment_time)
        allow(described_class).to receive(:can_approve_forked_pr?).and_return(true)

        expect(described_class).not_to receive(:launch_pipeline)

        described_class.run(@workflow, @logger)
      end

      it "persists a typed approval record and launches when authorized and enabled" do
        workflow = build_blocked_pr_workflow(project_id: @workflow.project_id, pr_number: 1)

        allow(@workflow.payload).to receive_messages(
          issue_number: 1,
          pr_approval?: true,
          pr_approval_include_secrets?: true,
          pr_approval_enable_cache?: true,
          comment_author: "maintainer",
          comment_author_uid: 4242,
          comment_id: 42,
          comment_created_at: approval_comment_time
        )
        allow(described_class).to receive_messages(
          approval_option_enabled?: true,
          can_approve_forked_pr?: true,
          update_pr_data: ok_pr_data(workflow)
        )

        expect(described_class).to receive(:launch_pipeline).with(kind_of(Branch), workflow, @logger)

        described_class.run(@workflow, @logger)

        payload = JSON.parse(Workflow.find(workflow.id).request["payload"])
        expect(payload["semaphore_approval_include_secrets"]).to be(true)
        expect(payload["semaphore_approval_enable_cache"]).to be(true)

        record = payload["semaphore_approval"]
        expect(record["include_secrets"]).to be(true)
        expect(record["enable_cache"]).to be(true)
        expect(record["approver"]).to eq("maintainer")
        expect(record["approver_uid"]).to eq(4242)
        expect(record["approved_head_sha"]).to eq(workflow.commit_sha)
        expect(record["comment_id"]).to eq(42)
        expect(record["approved_at"]).to eq(approval_comment_time)
      end

      context "when an approved workflow did not launch on the first attempt" do
        def mark_approved(workflow, include_secrets: false, enable_cache: false)
          payload = JSON.parse(workflow.request["payload"]).merge(
            "semaphore_approval_include_secrets" => include_secrets,
            "semaphore_approval_enable_cache" => enable_cache,
            "semaphore_approval" => {
              "include_secrets" => include_secrets,
              "enable_cache" => enable_cache,
              "approver" => "first-maintainer",
              "approved_head_sha" => workflow.commit_sha
            }
          )
          workflow.update(:request => workflow.request.merge("payload" => payload.to_json))
          Workflow.find(workflow.id)
        end

        def approval_payload(workflow)
          JSON.parse(Workflow.find(workflow.id).request["payload"])
        end

        before do
          allow(@logger).to receive(:info)
          allow(Watchman).to receive(:increment)
        end

        it "clears options left by an earlier approval when the next approval is bare" do
          workflow = mark_approved(
            build_blocked_pr_workflow(project_id: @workflow.project_id, pr_number: 1),
            :include_secrets => true,
            :enable_cache => true
          )

          allow(@workflow.payload).to receive_messages(
            issue_number: 1,
            pr_approval?: true,
            comment_author: "maintainer",
            comment_author_uid: 4242,
            comment_created_at: approval_comment_time
          )
          allow(described_class).to receive_messages(
            can_approve_forked_pr?: true,
            update_pr_data: ok_pr_data(workflow)
          )

          expect(described_class).to receive(:launch_pipeline).with(kind_of(Branch), workflow, @logger)

          described_class.run(@workflow, @logger)

          payload = approval_payload(workflow)
          expect(payload["semaphore_approval_include_secrets"]).to be(false)
          expect(payload["semaphore_approval_enable_cache"]).to be(false)
          expect(payload["semaphore_approval"]).to include(
            "include_secrets" => false,
            "enable_cache" => false,
            "approver" => "maintainer",
            "approver_uid" => 4242
          )
          expect(RepoHost::Github::Payload.new(Workflow.find(workflow.id).request["payload"]).pr_approval_include_secrets?).to be(false)
        end

        it "records a bare approval with the approved head" do
          workflow = build_blocked_pr_workflow(project_id: @workflow.project_id, pr_number: 1)

          allow(@workflow.payload).to receive_messages(
            issue_number: 1,
            pr_approval?: true,
            comment_author: "maintainer",
            comment_created_at: approval_comment_time
          )
          allow(described_class).to receive_messages(
            can_approve_forked_pr?: true,
            update_pr_data: ok_pr_data(workflow)
          )

          described_class.run(@workflow, @logger)

          expect(approval_payload(workflow)["semaphore_approval"]).to include(
            "approver" => "maintainer",
            "approved_head_sha" => workflow.commit_sha
          )
        end

        it "resumes a rescheduled approved workflow instead of filtering it again" do
          workflow = mark_approved(build_blocked_pr_workflow(project_id: @workflow.project_id, pr_number: 1))
          allow(workflow.project).to receive_messages(build_forked_pr: true, allowed_contributors: "radwo")
          allow(described_class).to receive(:update_pr_data).and_return(ok_pr_data(workflow))

          expect(@logger).not_to receive(:info).with("skip-filtered-contributor")
          expect(described_class).to receive(:launch_pipeline).with(kind_of(Branch), workflow, @logger)

          described_class.run(workflow, @logger, "", "", 1)
        end

        it "fails closed when a rescheduled approved workflow's fork head moved" do
          workflow = mark_approved(build_blocked_pr_workflow(project_id: @workflow.project_id, pr_number: 1))
          allow(workflow.project).to receive_messages(build_forked_pr: true, allowed_contributors: "radwo")
          allow(described_class).to receive(:update_pr_data).and_return(ok_pr_data(workflow, head_sha: "pushed-after-approval"))

          expect(described_class).not_to receive(:launch_pipeline)

          described_class.run(workflow, @logger, "", "", 1)

          expect(Workflow.find(workflow.id).state).to eq(Workflow::STATE_PR_APPROVAL_STALE)
        end

        it "still filters a rescheduled workflow that was never approved" do
          workflow = build_blocked_pr_workflow(project_id: @workflow.project_id, pr_number: 1)
          allow(workflow.project).to receive_messages(build_forked_pr: true, allowed_contributors: "radwo")

          expect(described_class).not_to receive(:launch_pipeline)

          described_class.run(workflow, @logger, "", "", 1)

          expect(Workflow.find(workflow.id).state).to eq(Workflow::STATE_SKIP_FILTERED_CONTRIBUTOR)
        end
      end

      it "fails closed (no launch, no marker) when a requested option is disabled at project level" do
        workflow = build_blocked_pr_workflow(project_id: @workflow.project_id, pr_number: 1)

        allow(@logger).to receive(:info)
        allow(Watchman).to receive(:increment)
        allow(@workflow.payload).to receive_messages(
          issue_number: 1,
          pr_approval?: true,
          pr_approval_include_secrets?: true,
          pr_approval_enable_cache?: true,
          comment_author: "maintainer",
          comment_created_at: approval_comment_time
        )
        allow(described_class).to receive_messages(
          approval_option_enabled?: false,
          approval_enable_cache_option_enabled?: false,
          can_approve_forked_pr?: true
        )

        expect(described_class).not_to receive(:launch_pipeline)
        expect(Watchman).to receive(:increment).with("hooks.pr_approval.option_not_enabled")

        described_class.run(@workflow, @logger)

        # One-shot approval NOT consumed: no markers persisted and the workflow
        # stays blocked so the option can be enabled and the command re-issued.
        payload = JSON.parse(Workflow.find(workflow.id).request["payload"])
        expect(payload["semaphore_approval_include_secrets"]).to be_nil
        expect(payload["semaphore_approval_enable_cache"]).to be_nil
        expect(payload["semaphore_approval"]).to be_nil
      end

      it "fails closed when only one of the requested options is disabled" do
        build_blocked_pr_workflow(project_id: @workflow.project_id, pr_number: 1)

        allow(@logger).to receive(:info)
        allow(Watchman).to receive(:increment)
        allow(@workflow.payload).to receive_messages(
          issue_number: 1,
          pr_approval?: true,
          pr_approval_include_secrets?: true,
          pr_approval_enable_cache?: true,
          comment_author: "maintainer",
          comment_created_at: approval_comment_time
        )
        # include-secrets enabled, enable-cache disabled → the requested cache
        # option is unavailable, so the whole command fails closed.
        allow(described_class).to receive_messages(
          approval_option_enabled?: true,
          approval_enable_cache_option_enabled?: false,
          can_approve_forked_pr?: true
        )

        expect(described_class).not_to receive(:launch_pipeline)
        expect(Watchman).to receive(:increment).with("hooks.pr_approval.option_not_enabled")

        described_class.run(@workflow, @logger)
      end

      context "when the sem_approve_options feature is disabled for the organization" do
        before do
          allow(Semaphore::FeatureFlags).to receive(:enabled?).with(:sem_approve_options, anything).and_return(false)
          allow(@logger).to receive(:info)
          allow(Watchman).to receive(:increment)
        end

        it "fails closed for a requested option even when the project setting is on" do
          workflow = build_blocked_pr_workflow(project_id: @workflow.project_id, pr_number: 1)

          allow(@workflow.payload).to receive_messages(
            issue_number: 1,
            pr_approval?: true,
            pr_approval_include_secrets?: true,
            comment_author: "maintainer",
            comment_created_at: approval_comment_time
          )
          allow(described_class).to receive_messages(
            approval_option_enabled?: true,
            can_approve_forked_pr?: true,
            update_pr_data: ok_pr_data(workflow)
          )

          expect(described_class).not_to receive(:launch_pipeline)
          expect(Watchman).to receive(:increment).with("hooks.pr_approval.options_feature_disabled")

          described_class.run(@workflow, @logger)

          reloaded = Workflow.find(workflow.id)
          expect(reloaded.state).to eq(Workflow::STATE_SKIP_FILTERED_CONTRIBUTOR)
          expect(JSON.parse(reloaded.request["payload"])).not_to include("semaphore_approval", "semaphore_approval_include_secrets")
        end

        it "checks the flag for the project's organization" do
          build_blocked_pr_workflow(project_id: @workflow.project_id, pr_number: 1)

          allow(@workflow.payload).to receive_messages(
            issue_number: 1,
            pr_approval?: true,
            pr_approval_enable_cache?: true,
            comment_author: "maintainer",
            comment_created_at: approval_comment_time
          )
          allow(described_class).to receive(:can_approve_forked_pr?).and_return(true)

          expect(Semaphore::FeatureFlags).to receive(:enabled?)
            .with(:sem_approve_options, @workflow.project.organization_id)
            .and_return(false)

          described_class.run(@workflow, @logger)
        end

        it "still launches a bare approval without looking up the flag" do
          workflow = build_blocked_pr_workflow(project_id: @workflow.project_id, pr_number: 1)

          allow(@workflow.payload).to receive_messages(
            issue_number: 1,
            pr_approval?: true,
            comment_author: "maintainer",
            comment_created_at: approval_comment_time
          )
          allow(described_class).to receive_messages(
            can_approve_forked_pr?: true,
            update_pr_data: ok_pr_data(workflow)
          )

          expect(Semaphore::FeatureFlags).not_to receive(:enabled?)
          expect(described_class).to receive(:launch_pipeline).with(kind_of(Branch), workflow, @logger)

          described_class.run(@workflow, @logger)
        end
      end

      it "fails closed (STATE_PR_APPROVAL_STALE, no launch) when the fork head moved after approval" do
        workflow = build_blocked_pr_workflow(project_id: @workflow.project_id, pr_number: 1)

        allow(@logger).to receive(:info)
        allow(Watchman).to receive(:increment)
        allow(@workflow.payload).to receive_messages(
          issue_number: 1,
          pr_approval?: true,
          pr_approval_include_secrets?: true,
          comment_author: "maintainer",
          comment_created_at: approval_comment_time
        )
        allow(described_class).to receive_messages(
          approval_option_enabled?: true,
          can_approve_forked_pr?: true,
          # Live fork head differs from the approved (blocked) head → a commit
          # was injected between approval and launch.
          update_pr_data: ok_pr_data(workflow, head_sha: "attacker-pushed-sha")
        )

        expect(described_class).not_to receive(:launch_pipeline)
        expect(@logger).to receive(:info).with(
          "pr-approval-stale-head",
          hash_including(:approved_head_sha => workflow.commit_sha, :live_head_sha => "attacker-pushed-sha")
        )
        expect(Watchman).to receive(:increment).with("hooks.pr_approval.stale_head")

        described_class.run(@workflow, @logger)

        expect(Workflow.find(workflow.id).state).to eq(Workflow::STATE_PR_APPROVAL_STALE)
      end

      it "fails closed when the live PR head cannot be determined" do
        workflow = build_blocked_pr_workflow(project_id: @workflow.project_id, pr_number: 1)

        allow(@logger).to receive(:info)
        allow(Watchman).to receive(:increment)
        allow(@workflow.payload).to receive_messages(
          issue_number: 1,
          pr_approval?: true,
          comment_author: "maintainer",
          comment_created_at: approval_comment_time
        )
        allow(described_class).to receive_messages(
          can_approve_forked_pr?: true,
          # No :head_sha at all → treated as changed, fail closed.
          update_pr_data: [
            :ok,
            { :mergeable => true, :commit_author => "octocat", :merge_commit_sha => workflow.commit_sha, :ref => workflow.git_ref },
            nil
          ]
        )

        expect(described_class).not_to receive(:launch_pipeline)

        described_class.run(@workflow, @logger)

        expect(Workflow.find(workflow.id).state).to eq(Workflow::STATE_PR_APPROVAL_STALE)
      end

      it "does not launch workflow when option persistence fails" do
        workflow = FactoryBot.create(
          :workflow,
          :project_id => @workflow.project_id,
          :state => Workflow::STATE_SKIP_FILTERED_CONTRIBUTOR
        )
        workflow.update(:git_ref => "refs/pull/1/merge", :created_at => before_comment)
        workflow.update(:request => ActionController::Parameters.new("payload" => "{invalid-json"))

        allow(@workflow.payload).to receive_messages(
          issue_number: 1,
          pr_approval?: true,
          pr_approval_include_secrets?: true,
          comment_author: "maintainer",
          comment_created_at: approval_comment_time
        )
        allow(described_class).to receive_messages(
          approval_option_enabled?: true,
          can_approve_forked_pr?: true
        )

        expect(described_class).not_to receive(:launch_pipeline)

        described_class.run(@workflow, @logger)
      end

      it "does not launch workflow when the requestor cannot approve" do
        FactoryBot.create(
          :workflow,
          :project_id => @workflow.project_id,
          :state => Workflow::STATE_SKIP_FILTERED_CONTRIBUTOR
        ).update(:git_ref => "refs/pull/45/merge")

        allow(@workflow.payload).to receive_messages(issue_number: 45, pr_approval?: true, comment_author: "outsider")

        expect(described_class).not_to receive(:launch_pipeline)

        allow(described_class).to receive(:can_approve_forked_pr?).and_return(false)

        described_class.run(@workflow, @logger)
      end

      it "binds the approval to the workflow present at comment time, ignoring a later push" do
        reviewed = build_blocked_pr_workflow(project_id: @workflow.project_id, pr_number: 7, created_at: before_comment)
        # The contributor pushes again AFTER the maintainer's approval comment,
        # producing a newer blocked workflow for the same PR. It must never be
        # the one that gets selected (and granted secrets).
        build_blocked_pr_workflow(project_id: @workflow.project_id, pr_number: 7, created_at: after_comment)

        allow(@workflow.payload).to receive_messages(
          issue_number: 7,
          pr_approval?: true,
          pr_approval_include_secrets?: true,
          comment_author: "maintainer",
          comment_created_at: approval_comment_time
        )
        allow(described_class).to receive_messages(
          approval_option_enabled?: true,
          can_approve_forked_pr?: true,
          update_pr_data: ok_pr_data(reviewed)
        )

        # The reviewed (older) workflow is launched; the post-approval push is
        # never selected.
        expect(described_class).to receive(:launch_pipeline).with(kind_of(Branch), reviewed, @logger)

        described_class.run(@workflow, @logger)
      end

      it "fails closed when the only blocked workflow was created after the approval comment" do
        build_blocked_pr_workflow(project_id: @workflow.project_id, pr_number: 8, created_at: after_comment)

        allow(@workflow.payload).to receive_messages(
          issue_number: 8,
          pr_approval?: true,
          comment_author: "maintainer",
          comment_created_at: approval_comment_time
        )
        allow(described_class).to receive(:can_approve_forked_pr?).and_return(true)

        expect(described_class).not_to receive(:launch_pipeline)

        described_class.run(@workflow, @logger)
      end

      it "fails closed (STATE_PR_APPROVAL_STALE) when the approved head sha is blank" do
        workflow = build_blocked_pr_workflow(project_id: @workflow.project_id, pr_number: 9)
        workflow.update(:commit_sha => nil)

        allow(@logger).to receive(:info)
        allow(Watchman).to receive(:increment)
        allow(@workflow.payload).to receive_messages(
          issue_number: 9,
          pr_approval?: true,
          comment_author: "maintainer",
          comment_created_at: approval_comment_time
        )
        allow(described_class).to receive(:can_approve_forked_pr?).and_return(true)

        expect(described_class).not_to receive(:launch_pipeline)
        expect(Watchman).to receive(:increment).with("hooks.pr_approval.missing_head_sha")

        described_class.run(@workflow, @logger)

        expect(Workflow.find(workflow.id).state).to eq(Workflow::STATE_PR_APPROVAL_STALE)
      end

      it "fails closed when the approval comment timestamp is missing" do
        build_blocked_pr_workflow(project_id: @workflow.project_id, pr_number: 10)

        allow(@logger).to receive(:info)
        allow(Watchman).to receive(:increment)
        allow(@workflow.payload).to receive_messages(
          issue_number: 10,
          pr_approval?: true,
          comment_author: "maintainer",
          comment_created_at: nil
        )
        allow(described_class).to receive(:can_approve_forked_pr?).and_return(true)

        expect(described_class).not_to receive(:launch_pipeline)
        expect(Watchman).to receive(:increment).with("hooks.pr_approval.missing_comment_time")

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

          it "creates ref on github via exactly one create_ref call and no probe" do
            # `ensure_ref` is now create-only — the whole optimisation. If
            # this assertion ever loosens, the rate-limit win is gone.
            expect(repo_host).not_to receive(:reference)
            expect(repo_host).to receive(:create_ref)
              .with("renderedtext/plakatt", "refs/semaphoreci/foo", "foo")
              .once

            allow(repo_host).to receive(:commit).with("renderedtext/plakatt",
                                                      "97114836a47ff614e70e863df819f908877ee1c9").and_return(RepoHost::Github::Responses::Commit.commit)

            expect(described_class.run(@workflow, @logger)).to be_nil
          end

          it "builds on a rescheduled run with a single pull request fetch" do
            allow(repo_host).to receive(:create_ref)
            allow(repo_host).to receive(:commit).with("renderedtext/plakatt",
                                                      "97114836a47ff614e70e863df819f908877ee1c9").and_return(RepoHost::Github::Responses::Commit.commit)
            expect(described_class).to receive(:launch_pipeline)

            described_class.run(@workflow, @logger, "", "", 1)

            expect(repo_host).to have_received(:pull_request).once
          end

          it "treats ReferenceAlreadyExists as success and still proceeds" do
            # When the ref already exists in GitHub, `create_ref` raises
            # ReferenceAlreadyExists. `ensure_ref` rescues it (mirroring
            # the existing typed-exception convention for MaximumNumberOfStatuses
            # and HookExistsOnRepository) and continues to the commit lookup.
            expect(repo_host).not_to receive(:reference)
            expect(repo_host).to receive(:create_ref)
              .with("renderedtext/plakatt", "refs/semaphoreci/foo", "foo")
              .and_raise(::RepoHost::RemoteException::ReferenceAlreadyExists)
            allow(repo_host).to receive(:commit).with("renderedtext/plakatt",
                                                      "97114836a47ff614e70e863df819f908877ee1c9").and_return(RepoHost::Github::Responses::Commit.commit)

            expect(described_class.run(@workflow, @logger)).to be_nil
          end

          shared_examples "without_reference fallback" do |exception_class, exception_msg|
            it "falls back to :without_reference and records the workflow state when create_ref raises #{exception_class}" do
              expect(repo_host).not_to receive(:reference)
              allow(repo_host).to receive(:create_ref)
                .with("renderedtext/plakatt", "refs/semaphoreci/foo", "foo")
                .and_raise(exception_class, exception_msg)
              allow(repo_host).to receive(:commit).with("renderedtext/plakatt",
                                                        "97114836a47ff614e70e863df819f908877ee1c9").and_return(RepoHost::Github::Responses::Commit.commit)

              # Spy on logger.info so we can assert "without-reference" was
              # logged without blocking other downstream info calls.
              allow(@logger).to receive(:info)

              expect(described_class.run(@workflow, @logger)).to be_nil
              expect(@logger).to have_received(:info).with("without-reference")
              # The handler should not mark the workflow as a hard failure
              # state for the without-reference path; it falls through to
              # downstream branch/pipeline handling.
              expect(@workflow.reload.state).not_to eq(Workflow::STATE_UNAUTHORIZED_REPO)
              expect(@workflow.reload.state).not_to eq(Workflow::STATE_NOT_FOUND_REPO)
            end
          end

          include_examples "without_reference fallback",
                           ::RepoHost::RemoteException::Unauthorized, "no token"
          include_examples "without_reference fallback",
                           ::RepoHost::RemoteException::NotFound, "repo gone"

          it "propagates RepoHost::RemoteException::Unknown raised by create_ref" do
            # The without_reference rescue only catches Unauthorized + NotFound.
            # Other failure modes (invalid SHA, etc.) must surface to the caller
            # so the workflow doesn't silently appear to succeed.
            expect(repo_host).not_to receive(:reference)
            allow(repo_host).to receive(:create_ref)
              .with("renderedtext/plakatt", "refs/semaphoreci/foo", "foo")
              .and_raise(::RepoHost::RemoteException::Unknown, "invalid SHA")
            allow(repo_host).to receive(:commit).with("renderedtext/plakatt",
                                                      "97114836a47ff614e70e863df819f908877ee1c9").and_return(RepoHost::Github::Responses::Commit.commit)

            expect { described_class.run(@workflow, @logger) }.to raise_error(::RepoHost::RemoteException::Unknown)
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

            expect do
              described_class.run(@workflow, @logger)
            end.to raise_error(RepoHost::RemoteException::Unknown)
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

        context "and GitHub has not finished computing mergeability (mergeable is nil)" do
          let(:max_retries) { 3 }
          let(:reserve) { 1000 }

          before do
            allow(App).to receive_messages(:mergeable_unknown_max_retries => max_retries,
                                           :mergeable_unknown_rate_limit_reserve => reserve)
            allow(repo_host).to receive(:validate_token_presence!)
            allow(repo_host).to receive_messages(:pull_request => { :merge_commit_sha => "", :mergeable => nil },
                                                 :last_response_rate_limit_remaining => 5000)
            allow(described_class).to receive(:sleep) # skip get_pr_data poll backoff
          end

          it "reschedules the hook with an incremented retry count instead of building" do
            expect(described_class).not_to receive(:launch_pipeline)
            expect(Semaphore::RepoHost::Hooks::Handler::Worker)
              .to receive(:perform_in).with(2.minutes, @workflow.id, anything, anything, 1)
            expect(@logger).to receive(:info).with("pr-mergeable-unknown-rescheduled", anything)

            described_class.run(@workflow, @logger)

            expect(@workflow.reload.state).not_to eq(Workflow::STATE_PR_NON_MERGEABLE)
          end

          it "polls the pull request on the first run" do
            allow(Semaphore::RepoHost::Hooks::Handler::Worker).to receive(:perform_in)

            described_class.run(@workflow, @logger)

            expect(repo_host).to have_received(:pull_request).exactly(9).times
            expect(described_class).to have_received(:sleep).exactly(8).times
          end

          it "fetches the pull request once, without polling, on a rescheduled run" do
            expect(Semaphore::RepoHost::Hooks::Handler::Worker)
              .to receive(:perform_in).with(2.minutes, @workflow.id, anything, anything, 2)

            described_class.run(@workflow, @logger, "", "", 1)

            expect(repo_host).to have_received(:pull_request).once
            expect(described_class).not_to have_received(:sleep)
          end

          it "still reschedules on the last attempt before the budget is exhausted" do
            expect(Semaphore::RepoHost::Hooks::Handler::Worker)
              .to receive(:perform_in).with(2.minutes, @workflow.id, anything, anything, max_retries)

            described_class.run(@workflow, @logger, "", "", max_retries - 1)

            expect(@workflow.reload.state).not_to eq(Workflow::STATE_PR_NON_MERGEABLE)
          end

          it "gives up once retries are exhausted without emitting a spurious unmergeable event" do
            expect(Semaphore::RepoHost::Hooks::Handler::Worker).not_to receive(:perform_in)
            expect(described_class).not_to receive(:update_pull_request_mergeable)
            expect(@logger).to receive(:info).with("pr-mergeable-unknown-giving-up", hash_including(:retries => max_retries))

            described_class.run(@workflow, @logger, "", "", max_retries)

            expect(@workflow.reload.state).to eq(Workflow::STATE_PR_NON_MERGEABLE)
          end

          it "gives up instead of rescheduling when the rate limit is below the reserve" do
            allow(repo_host).to receive(:last_response_rate_limit_remaining).and_return(reserve - 1)
            expect(Semaphore::RepoHost::Hooks::Handler::Worker).not_to receive(:perform_in)
            expect(described_class).not_to receive(:update_pull_request_mergeable)
            expect(@logger).to receive(:info).with("pr-mergeable-unknown-giving-up", hash_including(:rate_limit_remaining => reserve - 1))

            described_class.run(@workflow, @logger)

            expect(@workflow.reload.state).to eq(Workflow::STATE_PR_NON_MERGEABLE)
          end

          it "reschedules when exactly the reserve is left" do
            allow(repo_host).to receive(:last_response_rate_limit_remaining).and_return(reserve)
            expect(Semaphore::RepoHost::Hooks::Handler::Worker)
              .to receive(:perform_in).with(2.minutes, @workflow.id, anything, anything, 1)

            described_class.run(@workflow, @logger)
          end

          it "reschedules when the response does not report a rate limit" do
            allow(repo_host).to receive(:last_response_rate_limit_remaining).and_return(nil)
            expect(Semaphore::RepoHost::Hooks::Handler::Worker)
              .to receive(:perform_in).with(2.minutes, @workflow.id, anything, anything, 1)

            described_class.run(@workflow, @logger)
          end

          it "never holds a retry back for the rate limit when the reserve is 0" do
            allow(App).to receive(:mergeable_unknown_rate_limit_reserve).and_return(0)
            allow(repo_host).to receive(:last_response_rate_limit_remaining).and_return(0)
            expect(Semaphore::RepoHost::Hooks::Handler::Worker)
              .to receive(:perform_in).with(2.minutes, @workflow.id, anything, anything, 1)

            described_class.run(@workflow, @logger)
          end
        end
      end
    end
  end

  describe ".approved_sem_approve_option" do
    it "records dropped options when the project setting is disabled" do
      expect(@logger).to receive(:info).with(
        "pr-approval-option-dropped",
        :option => "--include-secrets",
        :reason => "project_option_disabled"
      )
      expect(Watchman).to receive(:increment).with(
        "hooks.pr_approval.option_dropped",
        :tags => %w[include-secrets project_option_disabled]
      )

      result = described_class.approved_sem_approve_option(
        :requested => true,
        :enabled => false,
        :option => "--include-secrets",
        :logger => @logger
      )

      expect(result).to be(false)
    end

    it "returns false when the option was not requested" do
      result = described_class.approved_sem_approve_option(
        :requested => false,
        :enabled => true,
        :option => "--enable-cache",
        :logger => nil
      )

      expect(result).to be(false)
    end

    it "returns true when requested and the project setting is enabled" do
      result = described_class.approved_sem_approve_option(
        :requested => true,
        :enabled => true,
        :option => "--include-secrets",
        :logger => @logger
      )

      expect(result).to be(true)
    end
  end

  describe ".can_approve_forked_pr?" do
    let(:project) { @workflow.project }

    it "returns false for a blank uid" do
      expect(described_class.can_approve_forked_pr?(project, nil)).to be(false)
      expect(described_class.can_approve_forked_pr?(project, "")).to be(false)
    end

    it "returns false when there is no repo host account for the uid" do
      expect(described_class.can_approve_forked_pr?(project, 999_999)).to be(false)
    end

    context "with a known user" do
      let(:maintainer_uid) { 4242 }

      before do
        user = FactoryBot.create(:user)
        FactoryBot.create(:repo_host_account, :user => user, :login => "maintainer", :github_uid => maintainer_uid)
      end

      def stub_permissions(permissions)
        allow_any_instance_of(InternalApi::RBAC::RBAC::Stub)
          .to receive(:list_user_permissions)
          .and_return(InternalApi::RBAC::ListUserPermissionsResponse.new(:permissions => permissions))
      end

      it "returns true when the user (resolved by uid) has project.job.rerun" do
        stub_permissions(["project.view", "project.job.rerun"])

        expect(described_class.can_approve_forked_pr?(project, maintainer_uid)).to be(true)
      end

      it "defaults to requiring project.job.rerun" do
        stub_permissions(["project.view"])

        expect(described_class.can_approve_forked_pr?(project, maintainer_uid)).to be(false)
      end

      it "checks the requested permission" do
        stub_permissions(["project.view"])

        expect(described_class.can_approve_forked_pr?(project, maintainer_uid, :permission => "project.view")).to be(true)
        expect(described_class.can_approve_forked_pr?(project, maintainer_uid, :permission => "project.job.rerun")).to be(false)
      end

      it "resolves by immutable uid, not by the (reusable) login" do
        stub_permissions(["project.view", "project.job.rerun"])

        # A commenter whose GitHub uid is not linked to the authorized account
        # must be denied even though that account's login exists — logins are
        # renameable/reusable and must not grant a secret bypass.
        expect(described_class.can_approve_forked_pr?(project, 5_150)).to be(false)
      end

      it "fails closed when the RBAC call raises" do
        allow(Watchman).to receive(:increment)
        allow_any_instance_of(InternalApi::RBAC::RBAC::Stub)
          .to receive(:list_user_permissions)
          .and_raise(StandardError.new("rbac down"))

        expect(@logger).to receive(:error).with(
          "pr-approval-permission-check-failed",
          hash_including(:requestor_uid => maintainer_uid, :project_id => project.id)
        )
        expect(Watchman).to receive(:increment).with("hooks.pr_approval.permission_check_failed")

        expect(described_class.can_approve_forked_pr?(project, maintainer_uid, @logger)).to be(false)
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
