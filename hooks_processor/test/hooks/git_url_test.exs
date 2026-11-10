defmodule HooksProcessor.Hooks.GitUrl.Test do
  use ExUnit.Case, async: true

  alias HooksProcessor.Hooks.GitUrl

  describe "web_url/1" do
    test "derives the web URL from an ssh:// remote" do
      assert GitUrl.web_url("ssh://git@git.example.com/team/app.git") == "https://git.example.com/team/app"
    end

    test "drops the ssh port, which is not the port of the web UI" do
      assert GitUrl.web_url("ssh://git@git.example.com:2222/team/app.git") == "https://git.example.com/team/app"
    end

    test "keeps nested paths" do
      assert GitUrl.web_url("ssh://git@git.example.com/group/subgroup/app.git") ==
               "https://git.example.com/group/subgroup/app"
    end

    test "derives the web URL from an scp-like remote" do
      assert GitUrl.web_url("git@git.example.com:team/app.git") == "https://git.example.com/team/app"
    end

    test "derives the web URL from a git:// remote" do
      assert GitUrl.web_url("git://git.example.com/team/app.git") == "https://git.example.com/team/app"
    end

    test "strips the .git suffix and the user from an https remote and keeps its port" do
      assert GitUrl.web_url("https://ci@git.example.com:8443/team/app.git") == "https://git.example.com:8443/team/app"
    end

    test "keeps a plain http remote on http" do
      assert GitUrl.web_url("http://git.example.com/team/app") == "http://git.example.com/team/app"
    end

    test "ignores surrounding whitespace and a trailing slash" do
      assert GitUrl.web_url(" ssh://git@git.example.com/team/app.git/ \n") == "https://git.example.com/team/app"
    end

    test "returns nil when the remote has no owner/repository path" do
      assert GitUrl.web_url("ssh://git@git.example.com/app.git") == nil
    end

    test "returns nil for a local path" do
      assert GitUrl.web_url("/srv/git/app.git") == nil
    end

    test "returns nil for a blank or missing remote" do
      assert GitUrl.web_url("") == nil
      assert GitUrl.web_url(nil) == nil
    end
  end
end
