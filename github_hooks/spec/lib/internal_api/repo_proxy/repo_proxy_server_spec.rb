require "spec_helper"

RSpec.describe InternalApi::RepoProxy::RepoProxyServer do
  let(:server) { described_class.new }
  let(:call) { double }

  before do
    allow(call).to receive(:metadata).and_return({})
  end

  describe "#describe" do
    context "when hook exists" do
      before do
        @hook = FactoryBot.create(:workflow_with_branch)
        @payload = @hook.payload
        @user = FactoryBot.create(:user, :email => @payload.data["pusher"]["email"])

        @req = InternalApi::RepoProxy::DescribeRequest.new(:hook_id => @hook.id)
      end

      it "returns an OK response status" do
        response = server.describe(@req, call)

        expect(response.status).to eq(InternalApi::ResponseStatus.new(:code => InternalApi::ResponseStatus::Code::OK))
      end

      it "returns info about hook" do
        response = server.describe(@req, call)
        hook = response.hook

        expect(hook.hook_id).to eq(@hook.id)
        expect(hook.head_commit_sha).to eq(@payload.head)
        expect(hook.commit_message).to eq(@payload.head_commit_message)
        expect(hook.commit_range).to eq(@payload.commit_range)
        expect(hook.repo_host_url).to eq(@payload.data["repository"]["url"])
        expect(hook.semaphore_email).to eq(@user.email)
        expect(hook.repo_host_username).to eq(@payload.data["pusher"]["name"])
        expect(hook.repo_host_email).to eq(@payload.data["pusher"]["email"])
        expect(hook.user_id).to eq(@user.id)
        expect(hook.repo_host_avatar_url).to eq(@hook.author_avatar_url)
        expect(hook.git_ref_type).to eq(:BRANCH)
        expect(hook.pr_mergeable).to eq(@hook.branch.pull_request_mergeable == true)
      end

      it "uses the minimum number of queries" do
        query_count = count_queries_while do
          server.describe(@req, call)
        end

        # hook, branch and user
        expect(query_count).to eql(3)
      end
    end

    context "when pusher is not present" do
      it "return empty repo_host_username, and empty repo_host_email" do
        @hook = FactoryBot.create(:workflow_with_branch)

        payload = JSON.parse(@hook.request["payload"])
        payload["pusher"] = nil

        request = @hook.request
        request["payload"] = payload.to_json

        @hook.update(:request => request)

        req = InternalApi::RepoProxy::DescribeRequest.new(:hook_id => @hook.id)

        @response = server.describe(req, call)

        expect(@response.hook.repo_host_username).to eq("")
        expect(@response.hook.repo_host_email).to eq("")
      end
    end

    context "when hook doesn't exists" do
      before do
        @hook_id = SecureRandom.uuid

        req = InternalApi::RepoProxy::DescribeRequest.new(:hook_id => @hook_id)

        @response = server.describe(req, call)
      end

      it "returns a BAD_PARAM response status" do
        expect(@response.status).to eq(InternalApi::ResponseStatus.new(
                                         :code => InternalApi::ResponseStatus::Code::BAD_PARAM, :message => "Hook with id #{@hook_id} not found"
                                       ))
      end
    end
  end

  describe "#describe_many" do
    context "when all hook exists" do
      before do
        @hooks = FactoryBot.create_list(:workflow_with_branch, 3)
        @payloads = @hooks.map(&:payload)
        @user = FactoryBot.create(:user, :email => @payloads.first.data["pusher"]["email"])

        # shuffling in order to make sure that the request order mathes the response
        @req = InternalApi::RepoProxy::DescribeManyRequest.new(:hook_ids => @hooks.map(&:id).shuffle)
      end

      it "returns an OK response status" do
        response = server.describe_many(@req, call)

        expect(response.status).to eq(InternalApi::ResponseStatus.new(:code => InternalApi::ResponseStatus::Code::OK))
      end

      it "returns info about hook" do
        response = server.describe_many(@req, call)
        hooks = response.hooks

        expect(hooks.count).to eq(@hooks.count)

        expect(hooks.first.hook_id).to eq(@req.hook_ids.first)
        expect(hooks.first.head_commit_sha).to eq(@payloads.first.head)
        expect(hooks.first.commit_message).to eq(@payloads.first.head_commit_message)
        expect(hooks.first.repo_host_url).to eq(@payloads.first.data["repository"]["url"])
        expect(hooks.first.semaphore_email).to eq(@payloads.first.data["pusher"]["email"])
        expect(hooks.first.repo_host_username).to eq(@payloads.first.data["pusher"]["name"])
        expect(hooks.first.repo_host_email).to eq(@payloads.first.data["pusher"]["email"])
        expect(hooks.first.user_id).to eq(@user.id)
        expect(hooks.first.repo_host_avatar_url).to eq(@hooks.first.author_avatar_url)
        expect(hooks.first.pr_mergeable).to eq(@hooks.first.branch.pull_request_mergeable == true)
      end

      it "returns in the order as requested" do
        response = server.describe_many(@req, call)

        expect(response.hooks.map(&:hook_id)).to eq(@req.hook_ids)
      end

      it "uses the minimum number of queries" do
        query_count = count_queries_while do
          server.describe_many(@req, call)
        end

        expect(query_count).to eql(2)
      end
    end

    context "when no hooks exists" do
      before do
        @hook_ids = Array.new(3) { SecureRandom.uuid }

        req = InternalApi::RepoProxy::DescribeManyRequest.new(:hook_ids => @hook_ids)

        @response = server.describe_many(req, call)
      end

      it "returns a BAD_PARAM response status" do
        expect(@response.status).to eq(InternalApi::ResponseStatus.new(
                                         :code => InternalApi::ResponseStatus::Code::BAD_PARAM, :message => "Hooks with ids #{@hook_ids.join(", ")} not found"
                                       ))
      end
    end

    context "when some hooks exists" do
      before do
        @hook_ids = Array.new(3) { SecureRandom.uuid }
        @hooks = FactoryBot.create_list(:workflow_with_branch, 2)
        @all_ids = @hook_ids + @hooks.map(&:id)

        req = InternalApi::RepoProxy::DescribeManyRequest.new(:hook_ids => @all_ids)

        @response = server.describe_many(req, call)
      end

      it "returns a BAD_PARAM response status" do
        expect(@response.status).to eq(InternalApi::ResponseStatus.new(
                                         :code => InternalApi::ResponseStatus::Code::BAD_PARAM, :message => "Hooks with ids #{@hook_ids.join(", ")} not found"
                                       ))
      end
    end
  end

  describe "#list_blocked_hooks" do
    before do
      @hooks = FactoryBot.create_list(:workflow_with_branch, 3)
      @hooks.first.update(:state => Workflow::STATE_WHITELIST_BRANCH)
      @payloads = @hooks.map(&:payload)

      @req = InternalApi::RepoProxy::ListBlockedHooksRequest.new(:project_id => @hooks.first.project_id)
    end

    it "returns an OK response status" do
      response = server.list_blocked_hooks(@req, call)

      expect(response.status).to eq(InternalApi::ResponseStatus.new(:code => InternalApi::ResponseStatus::Code::OK))
    end

    it "returns info about hook" do
      response = server.list_blocked_hooks(@req, call)
      hooks = response.hooks

      expect(hooks.count).to eq(1)

      expect(hooks.first.hook_id).to eq(@hooks.first.id)
      expect(hooks.first.head_commit_sha).to eq(@payloads.first.head)
      expect(hooks.first.commit_message).to eq(@payloads.first.head_commit_message)
      expect(hooks.first.repo_host_url).to eq(@payloads.first.data["repository"]["url"])
      expect(hooks.first.semaphore_email).to eq("")
      expect(hooks.first.repo_host_username).to eq(@payloads.first.data["pusher"]["name"])
      expect(hooks.first.repo_host_email).to eq(@payloads.first.data["pusher"]["email"])
      expect(hooks.first.user_id).to eq("")
      expect(hooks.first.repo_host_avatar_url).to eq(@hooks.first.author_avatar_url)
      expect(hooks.first.pr_mergeable).to eq(@hooks.first.branch.pull_request_mergeable == true)
    end

    it "uses the minimum number of queries" do
      query_count = count_queries_while do
        server.list_blocked_hooks(@req, call)
      end

      expect(query_count).to eql(2)
    end
  end

  describe "#schedule_blocked_hook" do
    context "when the hook is present" do
      before do
        allow(Semaphore::RepoHost::Hooks::Handler).to receive(
          :launch_pipeline
        ).and_return({ :ppl_id => "ppl_id", :wf_id => "wf_id" })

        owner = FactoryBot.create(:user, :github_connection)
        project = FactoryBot.create(:project, :creator => owner)
        @hook = FactoryBot.create(
          :workflow_with_branch,
          :project => project,
          :state => Workflow::STATE_WHITELIST_BRANCH
        )
        @req = InternalApi::RepoProxy::ScheduleBlockedHookRequest.new(
          :hook_id => @hook.id, :project_id => @hook.project.id
        )
      end

      it "launches the pipeline" do
        expect(Semaphore::RepoHost::Hooks::Handler).to receive(:launch_pipeline).with(@hook.branch, @hook, anything)

        server.schedule_blocked_hook(@req, call)
      end

      it "returns an ok response" do
        response = server.schedule_blocked_hook(@req, call)

        expect(response.status).to eq(
          InternalApi::ResponseStatus.new(
            :code => InternalApi::ResponseStatus::Code::OK
          )
        )
      end
    end

    context "when hook doesn't exist" do
      before do
        @project_id = SecureRandom.uuid
        @hook_id = SecureRandom.uuid

        req = InternalApi::RepoProxy::ScheduleBlockedHookRequest.new(:hook_id => @hook_id, :project_id => @project_id)

        @response = server.schedule_blocked_hook(req, call)
      end

      it "returns a BAD_PARAM response status" do
        expect(@response.status).to eq(InternalApi::ResponseStatus.new(
                                         :code => InternalApi::ResponseStatus::Code::BAD_PARAM, :message => "Hook with id #{@hook_id} not found"
                                       ))
      end
    end
  end
end
