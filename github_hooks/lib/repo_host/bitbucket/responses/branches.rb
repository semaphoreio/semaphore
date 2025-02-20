module RepoHost::Bitbucket::Responses
  class Branches
    def self.parse(response)
      response.map do |key, _val|
        branch_hash = { "name" => key }
        RepoHost::Responses::Format::Branch.new(branch_hash).to_h
      end
    end

    def self.parse_as_branch_head(response)
      branch_head_hash = { "sha" => response["hash"],
                           "html_url" => response["links"]["html"]["href"],
                           "author_name" => get_author_name(response),
                           "author_email" => get_author_email(response),
                           "author_date" => response["date"],
                           "message" => response["message"] }

      RepoHost::Responses::Format::BranchHead.new(branch_head_hash).to_h
    end

    def self.parse_as_commit(response)
      branch_commit_hash = { "sha" => response["hash"],
                             "html_url" => response["links"]["html"],
                             "author_name" => get_author_name(response),
                             "author_email" => get_author_email(response),
                             "author_date" => response["date"],
                             "message" => response["message"] }

      RepoHost::Responses::Format::BranchCommit.new(branch_commit_hash).to_h
    end

    private

    def self.get_author_name(response)
      response["author"]["raw"].split("<").first.rstrip
    end

    def self.get_author_email(response)
      response["author"]["raw"].split(" ").last.delete(">").delete("<")
    end
  end
end
