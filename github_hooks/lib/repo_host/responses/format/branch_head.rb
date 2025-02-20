module RepoHost::Responses::Format
  class BranchHead
    def initialize(branch_hash)
      @sha = branch_hash["sha"]
      @html_url = branch_hash["html_url"]
      @author_name = branch_hash["author_name"]
      @author_email = branch_hash["author_email"]
      @author_date = branch_hash["author_date"]
      @message = branch_hash["message"]
    end

    def to_h
      {
        "commit" => { "sha" => @sha,
                      "html_url" => @html_url,
                      "commit" => { "author" => { "name" => @author_name,
                                                  "email" => @author_email,
                                                  "date" => @author_date },
                                    "message" => @message } }
      }
    end
  end
end
