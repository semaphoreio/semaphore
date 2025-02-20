module RepoHost::Github::Responses::User

  def self.user(options = {})
    login = options[:login] ||= "octocat"
    id = options[:id] ||= 1
    {
      "login" => login,
      "id" => id,
      "avatar_url" => "https://github.com/images/error/octocat_happy.gif",
      "url" => "https://api.github.com/users/octocat",
      "name" => "monalisa octocat",
      "company" => "GitHub",
      "blog" => "https://github.com/blog",
      "location" => "San Francisco",
      "email" => "octocat@github.com",
      "hireable" => false,
      "bio" => "There once was...",
      "public_repos" => 2,
      "public_gists" => 1,
      "followers" => 20,
      "following" => 0,
      "html_url" => "https://github.com/octocat",
      "created_at" => "2008-01-14T04:33:35Z",
      "type" => "User"
    }
  end

  def self.emails
    [
      "octocat@github.com",
      "support@github.com"
    ]
  end

  def self.repositories
    [
      {
        "open_issues" => 0,
        "ssh_url" => "git@github.com:miloshadzic/color-theme-radiance.git",
        "url" => "https://api.github.com/repos/miloshadzic/color-theme-radiance",
        "homepage" => "",
        "language" => "Emacs Lisp",
        "forks" => 3,
        "fork" => false,
        "clone_url" => "https://github.com/miloshadzic/color-theme-radiance.git",
        "created_at" => "2011-03-12T13:40:44Z",
        "master_branch" => nil,
        "watchers" => 22,
        "private" => false,
        "size" => 316,
        "git_url" => "git://github.com/miloshadzic/color-theme-radiance.git",
        "owner" => {
          "url" => "https://api.github.com/users/miloshadzic",
          "login" => "miloshadzic",
          "avatar_url" => "https://secure.gravatar.com/avatar/c6d29c2892e6f88e7497a5c2dde9d08f?d=https://gs1.wac.edgecastcdn.net/80460E/assets%2Fimages%2Fgravatars%2Fgravatar-140.png",
          "id" => 93555
        },
        "description" => "A light Emacs theme that should go well with Ubuntu's light theme.",
        "name" => "color-theme-radiance",
        "html_url" => "https://github.com/miloshadzic/color-theme-radiance",
        "pushed_at" => "2011-03-28T00:34:26Z",
        "svn_url" => "https://svn.github.com/miloshadzic/color-theme-radiance"
      },
      {
        "open_issues" => 0,
        "ssh_url" => "git@github.com:miloshadzic/dotfiles.git",
        "url" => "https://api.github.com/repos/miloshadzic/dotfiles",
        "homepage" => "",
        "language" => "VimL",
        "forks" => 1,
        "fork" => false,
        "clone_url" => "https://github.com/miloshadzic/dotfiles.git",
        "created_at" => "2011-06-06T23:25:36Z",
        "master_branch" => nil,
        "watchers" => 1,
        "private" => false,
        "size" => 196,
        "git_url" => "git://github.com/miloshadzic/dotfiles.git",
        "owner" => {
          "url" => "https://api.github.com/users/miloshadzic",
          "login" => "miloshadzic",
          "avatar_url" => "https://secure.gravatar.com/avatar/c6d29c2892e6f88e7497a5c2dde9d08f?d=https://gs1.wac.edgecastcdn.net/80460E/assets%2Fimages%2Fgravatars%2Fgravatar-140.png",
          "id" => 93555
        },
        "description" => "",
        "name" => "dotfiles",
        "html_url" => "https://github.com/miloshadzic/dotfiles",
        "pushed_at" => "2011-07-06T08:35:48Z",
        "svn_url" => "https://svn.github.com/miloshadzic/dotfiles"
      },
      {
        "url" => "https://api.github.com/repos/miloshadzic/rubinius",
        "pushed_at" => "2011-05-13T08:42:32Z",
        "forks" => 0,
        "homepage" => "http://rubini.us",
        "watchers" => 1,
        "master_branch" => "master",
        "language" => "Ruby",
        "html_url" => "https://github.com/miloshadzic/rubinius",
        "fork" => true,
        "git_url" => "git://github.com/miloshadzic/rubinius.git",
        "clone_url" => "https://github.com/miloshadzic/rubinius.git",
        "created_at" => "2011-05-13T10:01:31Z",
        "open_issues" => 0,
        "private" => false,
        "size" => 12468,
        "owner" => {
          "url" => "https://api.github.com/users/miloshadzic",
          "avatar_url" => "https://secure.gravatar.com/avatar/c6d29c2892e6f88e7497a5c2dde9d08f?d=https://gs1.wac.edgecastcdn.net/80460E/assets%2Fimages%2Fgravatars%2Fgravatar-140.png",
          "login" => "miloshadzic",
          "id" => 93555
        },
        "name" => "rubinius",
        "ssh_url" => "git@github.com:miloshadzic/rubinius.git",
        "description" => "Rubinius, the Ruby VM",
        "svn_url" => "https://svn.github.com/miloshadzic/rubinius"
      }
    ]
  end

  def self.organizations
    [
      {
        "avatar_url" => "https://secure.gravatar.com/avatar/7c1f2250f5f193cd60d4bc3b569be862?d=https://gs1.wac.edgecastcdn.net/80460E/assets%2Fimages%2Fgravatars%2Fgravatar-orgs.png",
        "url" => "https://api.github.com/orgs/renderedtext",
        "login" => "renderedtext",
        "id" => 224711
      }
    ]
  end

end
