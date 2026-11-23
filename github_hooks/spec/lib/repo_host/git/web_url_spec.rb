require "spec_helper"

RSpec.describe RepoHost::Git::WebUrl do
  describe ".derive" do
    it "derives the web URL from an ssh:// remote" do
      expect(described_class.derive("ssh://git@git.example.com/team/app.git")).to eq("https://git.example.com/team/app")
    end

    it "drops the ssh port, which is not the port of the web UI" do
      expect(described_class.derive("ssh://git@git.example.com:2222/team/app.git")).to eq("https://git.example.com/team/app")
    end

    it "keeps nested paths" do
      expect(described_class.derive("ssh://git@git.example.com/group/subgroup/app.git")).to eq("https://git.example.com/group/subgroup/app")
    end

    it "derives the web URL from an scp-like remote" do
      expect(described_class.derive("git@git.example.com:team/app.git")).to eq("https://git.example.com/team/app")
    end

    it "derives the web URL from a git:// remote" do
      expect(described_class.derive("git://git.example.com/team/app.git")).to eq("https://git.example.com/team/app")
    end

    it "strips the .git suffix and the user from an https remote and keeps its port" do
      expect(described_class.derive("https://ci@git.example.com:8443/team/app.git")).to eq("https://git.example.com:8443/team/app")
    end

    it "keeps a plain http remote on http" do
      expect(described_class.derive("http://git.example.com/team/app")).to eq("http://git.example.com/team/app")
    end

    it "ignores surrounding whitespace and a trailing slash" do
      expect(described_class.derive(" ssh://git@git.example.com/team/app.git/ \n")).to eq("https://git.example.com/team/app")
    end

    it "returns nil when the remote has no owner/repository path" do
      expect(described_class.derive("ssh://git@git.example.com/app.git")).to be_nil
    end

    it "returns nil for a local path" do
      expect(described_class.derive("/srv/git/app.git")).to be_nil
    end

    it "returns nil for a blank remote" do
      expect(described_class.derive(nil)).to be_nil
      expect(described_class.derive("")).to be_nil
    end
  end
end
