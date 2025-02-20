module RepoHost::Bitbucket::Responses
  class DeprecatedPayload
    def self.parse(payload, project_id)
      DeprecatedPayload.new(payload, project_id).parse
    end

    def initialize(payload, project_id)
      @payload = payload
      @project = Project.find_by_id(project_id)
      @commits = payload["commits"]
      @new_payload = {}
    end

    def parse
      @new_payload.merge!(extract_action)
      @new_payload.merge!(extract_commits)
      @new_payload.merge!(extract_branch_name)
      @new_payload.merge!(extract_head_commit)
      @new_payload.merge!(extract_prev_head_commit)

      @new_payload
    end

    private

    def extract_action
      if @project.present? && @project.find_branch(@commits.last["branch"]).blank?
        { "created" => true }
      else
        {}
      end
    end

    def extract_commits
      commits = @payload["commits"].map do |commit|
        {
          "message" => commit["message"],
          "id" => commit["raw_node"],
          "url" => extract_commit_url(commit),
          "author" => extract_commit_author(commit),
          "timestamp" => commit["timestamp"]
        }
      end

      { "commits" => commits }
    end

    def extract_branch_name
      { "ref" => "refs/heads/#{@commits.last["branch"]}" }
    end

    def extract_head_commit
      { "after" => @commits.last["raw_node"] }
    end

    def extract_prev_head_commit
      { "before" => @commits.last["parents"].last }
    end

    def extract_commit_author_email(raw_author)
      raw_author.split(" ").last.delete(">").delete("<")
    end

    def extract_commit_url(commit)
      "https://bitbucket.org#{@payload["repository"]["absolute_url"]}commits/#{commit["raw_node"]}"
    end

    def extract_commit_author(commit)
      { "name" => commit["author"], "email" => extract_commit_author_email(commit["raw_author"]) }
    end
  end
end
