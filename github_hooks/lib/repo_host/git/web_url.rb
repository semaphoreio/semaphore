# frozen_string_literal: true

module RepoHost::Git
  # Derives the browsable (web) URL of a repository from the git remote
  # configured on a generic git project. Generic git hooks carry no repository
  # information, so the remote is the only thing we know about the repository:
  #
  #   ssh://git@git.example.com:2222/team/app.git -> https://git.example.com/team/app
  #   git@git.example.com:team/app.git            -> https://git.example.com/team/app
  #   https://git.example.com/team/app.git        -> https://git.example.com/team/app
  #
  # The result follows the convention shared by Forgejo, Gitea, Gogs, GitLab
  # and GitHub, which all serve the repository at https://<host>/<path>. Returns
  # nil when no web URL can be derived.
  module WebUrl
    SCHEMES = %w[ssh git http https].freeze
    SCP_LIKE = %r{\A(?:[^@/\s]+@)?(?<host>[^:/\s]+):(?<path>\S+)\z}

    def self.derive(remote)
      return nil if remote.blank?

      remote = remote.strip
      uri = parse(remote)

      if uri
        build(web_scheme(uri), authority(uri), uri.path)
      elsif (scp = SCP_LIKE.match(remote))
        build("https", scp[:host], scp[:path])
      end
    end

    def self.parse(remote)
      uri = URI.parse(remote)
      uri if uri.host.present? && SCHEMES.include?(uri.scheme)
    rescue URI::InvalidURIError
      nil
    end
    private_class_method :parse

    def self.web_scheme(uri)
      uri.scheme.start_with?("http") ? uri.scheme : "https"
    end
    private_class_method :web_scheme

    # Only an http(s) remote tells us the port of the web server; the port of
    # an ssh remote is the port of sshd and says nothing about the web UI.
    def self.authority(uri)
      if uri.scheme.start_with?("http") && uri.port != uri.default_port
        "#{uri.host}:#{uri.port}"
      else
        uri.host
      end
    end
    private_class_method :authority

    def self.build(scheme, authority, path)
      segments = path.to_s.sub(%r{/+\z}, "").delete_suffix(".git").split("/").reject(&:blank?)
      return nil if segments.size < 2

      "#{scheme}://#{authority}/#{segments.join("/")}"
    end
    private_class_method :build
  end
end
