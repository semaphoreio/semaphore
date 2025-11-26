module InternalApi
  module RepoProxy
    module UserInfo
      private

      def user_info(user)
        repo_host_account = user.github_repo_host_account
        name = user.respond_to?(:name) ? user.name : nil
        email = user.respond_to?(:email) ? user.email : nil
        github_uid = repo_host_account&.github_uid
        avatar = github_uid ? ::Avatar.avatar_url(github_uid) : nil
        login = repo_host_account&.login

        [name.presence || repo_host_account&.name || "", email.to_s, github_uid, avatar, login]
      end
    end
  end
end
