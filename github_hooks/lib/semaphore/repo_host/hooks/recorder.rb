class Semaphore::RepoHost::Hooks::Recorder

  def self.record_hook(params, project)
    params[:payload] = encoded_params_payload(params)

    request = create_post_commit_request(params, project)

    set_commit_sha(request)
    set_commit_author(request)
    set_git_ref(request)

    request

  rescue Exception => ex
    Exceptions.notify(ex, :project_hash_id => project.id)
  end

  def self.create_post_commit_request(params, project)
    Workflow.create!(
      :project_id => project.id,
      :repository_id => project.repository.id,
      :organization_id => project.organization_id,
      :request => params,
      :provider => "github",
      :state => Workflow::STATE_PROCESSING
    )
  end

  def self.encoded_params_payload(params)
    params[:payload].try(:super_encode_to_utf8)
  end

  def self.set_commit_sha(workflow)
    commit_sha = workflow.payload.head

    workflow.update(:commit_sha => commit_sha)
  end

  def self.set_commit_author(workflow)
    commit_author = workflow.payload.commit_author

    workflow.update(:commit_author => commit_author)
  end

  def self.set_git_ref(workflow)
    ref = workflow.payload.ref

    workflow.update(:git_ref => ref)
  end
end
