module RepoHost
  class StatusBody < PresenterBase
    CONTEXT = "semaphoreci"

    def initialize(build)
      @build = build
      @project = build.branch.project
    end

    def body
      raise NotImplementedError
    end

    private

    def status
      raise NotImplementedError
    end

    def description
      if @build.passed?
        "The build passed on Semaphore."
      elsif @build.finished?
        "The build failed on Semaphore."
      else
        "The build is pending on Semaphore."
      end
    end

    def url
      App.base_url + r.owner_project_branch_build_path(@project.organization, @project, @build.branch, @build)
    end
  end
end
