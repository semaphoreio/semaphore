module InternalApi
  module RepoProxy
    class RepoProxyServer < RepoProxyService::Service
      extend InternalApi::GrpcDsl
      include Semaphore::Grpc::ResponseStatus

      rpc_metric_namespace "repo_proxys_api"

      define_rpc :describe do |req|
        hook = ::Workflow.find_by(:id => req.hook_id)

        if hook.present?
          user = ::User.find_by(:email => hook.author_email)
          InternalApi::RepoProxy::DescribeResponse.new(
            :status => grpc_status_ok,
            :hook => present_hook(hook, user))
        else
          InternalApi::RepoProxy::DescribeResponse.new(
            :status => grpc_status_bad_param("Hook with id #{req.hook_id} not found")
          )
        end
      end

      define_rpc :describe_many do |req|
        hooks = Watchman.benchmark("describe_many_hooks.get_hooks", tags: [req.hook_ids.count]) do
          ::Workflow.where(:id => req.hook_ids.to_a)
            .includes(:branch)
            .references(:branch)
            .sort_by { |h| req.hook_ids.index(h.id) }
        end

        missing_hook_ids = req.hook_ids.uniq - hooks.map(&:id)

        if missing_hook_ids.empty?
          users = Watchman.benchmark("describe_many_hooks.get_users", tags: [req.hook_ids.count]) do
            ::User.where(:email => hooks.map { |hook| hook.author_email }).to_a
          end

          Watchman.benchmark("describe_many_hooks.construct_response", tags: [req.hook_ids.count]) do
            InternalApi::RepoProxy::DescribeManyResponse.new(
              :status => grpc_status_ok,
              :hooks => hooks.map { |hook|
                user = users.find { |u| u.email == hook.author_email }
                present_hook(hook, user)
              })
          end
        else
          InternalApi::RepoProxy::DescribeManyResponse.new(
            :status => grpc_status_bad_param("Hooks with ids #{missing_hook_ids.join(", ")} not found")
          )
        end
      end

      define_rpc :create_blank do |req, logger|
        project = ::Project.find(req.project_id)
        user    = ::User.find(req.requester_id)

        payload_builder = InternalApi::RepoProxy::PayloadFactory.create(req.git.reference, req.git.commit_sha)
        payload = payload_builder.call(project, user)

        params = ActionController::Parameters.new
        params["hash_id"] = project.id
        params["payload"] = payload.to_json

        workflow = ::Semaphore::RepoHost::Hooks::Recorder.record_hook(params, project)
        workflow.update(:result => ::Workflow::RESULT_OK)

        branch = ::Branch.find_or_create_for_workflow(workflow)
        branch.unarchive
        workflow.update(:branch_id => branch.id)

        if workflow.payload.pull_request?
          branch.update(:pull_request_mergeable => true)
          workflow.update(
            :commit_author => payload["commit_author"],
            :commit_sha => payload["merge_commit_sha"],
            :git_ref => payload["semaphore_ref"]
          )
        end

        workflow.update(:ppl_id => req.pipeline_id)
        workflow.update(:wf_id => req.wf_id)
        workflow.update(:state => Workflow::STATE_LAUNCHING)

        InternalApi::RepoProxy::CreateBlankResponse.new(
          :hook_id => workflow.id,
          :wf_id => req.wf_id,
          :pipeline_id => req.pipeline_id,
          :branch_id => branch.id,
          :repo => InternalApi::RepoProxy::CreateBlankResponse::Repo.new(
            :owner => branch.project.repository.owner,
            :repo_name => branch.project.repository.name,
            :branch_name => branch.name,
            :commit_sha => workflow.commit_sha,
            :repository_id => branch.project.repository.id
          )
        )

      rescue ::InternalApi::RepoProxy::PrPayload::PrNotMergeableError => e
        raise GRPC::Aborted, e.message
      rescue ::InternalApi::RepoProxy::PayloadFactory::InvalidReferenceError => e
        raise GRPC::InvalidArgument, e.message
      rescue ::RepoHost::RemoteException::NotFound
        raise GRPC::NotFound, "Reference not found on GitHub #{req.git.reference} #{req.git.commit_sha}"
      rescue ::RepoHost::RemoteException::Unknown => e
        logger.error("Unknown error", error: e.message)
        raise GRPC::Internal, "Unknown error"
      rescue ::ActiveRecord::RecordNotFound => e
        raise GRPC::NotFound, e.message
      end

      define_rpc :create do |req, logger|
        project = ::Project.find(req.project_id)

        if project.repository.integration_type.include?("github")
          create_for_github_project(req, logger)
        else
          create_via_hooks_api(req)
        end
      end

      def create_via_hooks_api(req)
        client = InternalApi::RepoProxy::RepoProxyService::Stub.new(App.hooks_api_url, :this_channel_is_insecure)
        client.create(req)
      end

      def create_for_github_project(req, logger)
        project = ::Project.find(req.project_id)
        user    = ::User.find(req.requester_id)

        payload_builder = InternalApi::RepoProxy::PayloadFactory.create(req.git.reference, req.git.commit_sha)
        payload = payload_builder.call(project, user)

        params = ActionController::Parameters.new
        params["hash_id"] = project.id
        params["payload"] = payload.to_json

        workflow = ::Semaphore::RepoHost::Hooks::Recorder.record_hook(params, project)
        workflow.update(:result => ::Workflow::RESULT_OK)

        branch = ::Branch.find_or_create_for_workflow(workflow)
        branch.unarchive
        workflow.update(:branch_id => branch.id)

        if workflow.payload.pull_request?
          branch.update(:pull_request_mergeable => true)
          workflow.update(
            :commit_author => payload["commit_author"],
            :commit_sha => payload["merge_commit_sha"],
            :git_ref => payload["semaphore_ref"]
          )
        end

        label =
          if workflow.payload.pull_request?
            workflow.pull_request_number.to_s
          elsif workflow.payload.tag_created?
            workflow.payload.tag_name
          else
            workflow.branch_name
          end

        client  = InternalApi::PlumberWF::WorkflowService::Stub.new(App.plumber_internal_url, :this_channel_is_insecure)
        request = InternalApi::PlumberWF::ScheduleRequest.new(
          :service => InternalApi::PlumberWF::ScheduleRequest::ServiceType::GIT_HUB,
          :repo => InternalApi::PlumberWF::ScheduleRequest::Repo.new(
            :owner => branch.project.repository.owner,
            :repo_name => branch.project.repository.name,
            :branch_name => branch.name,
            :commit_sha => workflow.commit_sha
          ),
          :project_id => branch.project_id,
          :branch_id => branch.id,
          :hook_id => workflow.id,
          :request_token => req.request_token,
          :snapshot_id => "",
          :definition_file => req.definition_file.presence || branch.project.repository.pipeline_file,
          :requester_id => user.id,
          :organization_id => branch.project.organization_id,
          :label => label,
          :triggered_by => req.triggered_by
        )

        response = client.schedule(request)

        if response.status.code == :OK
          #logger.info("Processing Hook #{workflow.id} => Plumber responded with #{response.status.code} code")

          duration = Time.zone.now.to_ms - workflow.created_at.to_ms
          Watchman.submit("hook.processing.duration", duration, :timing)

          workflow.update(:ppl_id => response.ppl_id)
          workflow.update(:state => Workflow::STATE_LAUNCHING)

          InternalApi::RepoProxy::CreateResponse.new(
            :hook_id => workflow.id,
            :workflow_id => response.wf_id,
            :pipeline_id => response.ppl_id
          )
        else
          workflow.update(:state => Workflow::STATE_LAUNCHING_FAILED)
          raise GRPC::InvalidArgument, "The Plumber returned #{response.status.inspect}"
        end

      rescue ::InternalApi::RepoProxy::PrPayload::PrNotMergeableError => e
        workflow.update(:state => Workflow::STATE_PR_NON_MERGEABLE)
        raise GRPC::Aborted, e.message
      rescue ::InternalApi::RepoProxy::PayloadFactory::InvalidReferenceError => e
        workflow.update(:state => Workflow::STATE_LAUNCHING_FAILED)
        raise GRPC::InvalidArgument, e.message
      rescue ::RepoHost::RemoteException::NotFound
        workflow.update(:state => Workflow::STATE_NOT_FOUND_REPO)
        raise GRPC::NotFound, "Reference not found on GitHub #{req.git.reference} #{req.git.commit_sha}"
      rescue ::RepoHost::RemoteException::Unknown => e
        logger.error("Unknown error", error: e.message)
        raise GRPC::Unknown, "Unknown error"
      rescue ::ActiveRecord::RecordNotFound => e
        if e.model == User
          raise GRPC::NotFound, "Requester not found #{req.requester_id}"
        else
          raise GRPC::NotFound, "Project not found #{req.project_id}"
        end
      end

      define_rpc :list_blocked_hooks do |req|
        sub_query =
          if req.git_ref.present?
            ::Workflow
              .select("DISTINCT ON (git_ref) id")
              .in_project(req.project_id)
              .blocked_by_whitelist
              .where(["git_ref ILIKE ?", "%#{req.git_ref}%"])
              .limit(100)
              .order("git_ref, created_at DESC")
          else
            ::Workflow
              .select("DISTINCT ON (git_ref) id")
              .in_project(req.project_id)
              .blocked_by_whitelist
              .limit(100)
              .order("git_ref, created_at DESC")
          end

        hooks = ::Workflow.where(:id => sub_query).preload(:branch)

        InternalApi::RepoProxy::ListBlockedHooksResponse.new(
          :status => grpc_status_ok,
          :hooks => hooks.map { |hook| present_hook(hook, nil) })
      end

      define_rpc :schedule_blocked_hook do |req, logger|
        hook = ::Workflow.blocked_by_whitelist.in_project(req.project_id).find_by(:id => req.hook_id)

        if hook.present?
          logger.add(:post_commit_request_id => hook.id)

          branch = Semaphore::RepoHost::Hooks::Handler.find_or_create_branch(hook, logger)
          data = Semaphore::RepoHost::Hooks::Handler.launch_pipeline(branch, hook, logger)

          InternalApi::RepoProxy::ScheduleBlockedHookResponse.new(
            :status => grpc_status_ok,
            :ppl_id => data[:ppl_id],
            :wf_id => data[:wf_id]
          )
        else
          InternalApi::RepoProxy::ScheduleBlockedHookResponse.new(
            :status => grpc_status_bad_param("Hook with id #{req.hook_id} not found")
          )
        end
      end

      private

      def present_hook(hook, user)
        data = {
          :hook_id => hook.id,
          :head_commit_sha => hook.commit_sha.to_s,
          :commit_message => commit_message(hook),
          :commit_range => hook.payload.commit_range,
          :commit_author => (hook.commit_author.presence || hook.payload.commit_author).to_s,
          :repo_host_url => hook.repo_url.to_s,
          :repo_host_username => hook.author_name.to_s,
          :repo_host_email => hook.author_email.to_s,
          :repo_host_avatar_url => hook.author_avatar_url.to_s,
          :repo_host_uid => hook.author_uid.to_s,
          :repo_slug => hook.payload.repo_name.to_s,
          :git_ref => hook.git_ref,
          :git_ref_type => type(hook),
          :pr_slug => hook.payload.pr_head_repo_name.to_s,
          :pr_name => hook.pull_request_name.to_s,
          :pr_number => hook.pull_request_number.to_s,
          :pr_sha => hook.payload.pr_head_sha.to_s,
          :pr_branch_name => hook.payload.pr_head_branch_name.to_s,
          :pr_mergeable => pr_mergeable(hook),
          :tag_name => hook.payload.tag_name.to_s,
          :branch_name => branch_name(hook)
        }

        if user.present?
          data[:user_id] = user.id
          data[:semaphore_email] = user.email
        end

        ::InternalApi::RepoProxy::Hook.new(data)
      end

      def pr_mergeable(hook)
        !!(hook.branch && hook.branch.pull_request_mergeable)
      end

      def branch_name(hook)
        if hook.payload.pull_request?
          hook.payload.pr_base_branch_name.to_s
        else
          hook.branch_name.to_s
        end
      end

      def type(hook)
        if hook.payload.pull_request?
          InternalApi::RepoProxy::Hook::Type::PR
        elsif hook.payload.tag?
          InternalApi::RepoProxy::Hook::Type::TAG
        else
          InternalApi::RepoProxy::Hook::Type::BRANCH
        end
      end

      def commit_message(hook)
        hook.payload.pull_request_name.presence || hook.commit_message.to_s
      end
    end
  end
end
