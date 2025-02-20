module Semaphore
  class Member

    def self.create(gh_user, organization, repo_host)
      new(gh_user, organization, repo_host).create
    end

    def initialize(gh_user, organization, repo_host)
      @gh_user = gh_user
      @organization = organization
      @repo_host = repo_host
    end

    def create
      ::Member.create!(
        :organization_id => @organization.id,
        :github_uid => @gh_user.id,
        :github_username => @gh_user.login,
        :invite_email => @gh_user.email,
        :repo_host => @repo_host
      ).tap do |member|
        User.find_by_provider_login(member.github_username, member.repo_host)&.unblock!
      end
    rescue ActiveRecord::RecordInvalid
      nil
    end
  end
end
