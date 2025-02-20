require "spec_helper"

RSpec.describe Project, :type => :model do
  let(:project) { FactoryBot.create(:project_with_branch) }

  it { is_expected.to belong_to(:organization) }
  it { is_expected.to belong_to(:creator) }

  it { is_expected.to have_one(:repository) }

  it { is_expected.to have_many(:branches) }
  it { is_expected.to have_many(:workflows) }

  describe "scopes" do
    describe "by_creator" do
      before do
        @user = FactoryBot.create(:user)
        @project_by_user = FactoryBot.create(:project, :creator => @user)
        @other_project = FactoryBot.create(:project)
      end

      it "returns projects created by the user" do
        expect(Project.by_creator(@user)).to include(@project_by_user)
      end

      it "doesn't return projects created by another user" do
        expect(Project.by_creator(@user)).not_to include(@other_project)
      end
    end

    describe ".with_repos" do
      before do
        @private_project = FactoryBot.create(:project, :with_private_repository)
        @public_project  = FactoryBot.create(:project, :with_public_repository)
      end

      context "when quering for private repositories" do
        it "returns projects with private repositories" do
          expect(Project.with_repos(:private => true)).to contain_exactly(@private_project)
        end
      end

      context "when quering for public repositories" do
        it "returns projects with public repositories" do
          expect(Project.with_repos(:private => false)).to contain_exactly(@public_project)
        end
      end
    end
  end

  describe "#organization" do
    context "when project belongs to organization" do
      before do
        @organization = FactoryBot.create(:organization)
        @project = FactoryBot.create(:project, :organization => @organization)
      end

      it "returns organization" do
        expect(@project.organization).to eq(@organization)
      end
    end
  end

  describe "github_repository?" do
    before do
      @project = FactoryBot.create(:project)
    end

    context "repository is from github" do
      it "returns true" do
        expect(@project.github_repository?).to be_truthy
      end
    end

    context "repository is from bitbucket" do
      before do
        allow(@project).to receive_message_chain(:repository, :provider) { Repository::BITBUCKET_PROVIDER }
      end

      it "returns false" do
        expect(@project.github_repository?).to be_falsey
      end
    end
  end

  describe "bitbucket_repository?" do
    before do
      @project = FactoryBot.create(:project)
    end

    context "repository is from bitbucket" do
      before do
        allow(@project).to receive_message_chain(:repository, :provider) { Repository::BITBUCKET_PROVIDER }
      end

      it "returns true" do
        expect(@project.bitbucket_repository?).to be_truthy
      end
    end

    context "repository is from bitbucket" do
      it "returns false" do
        expect(@project.bitbucket_repository?).to be_falsey
      end
    end
  end

  describe "#repo_owner_and_name" do
    context "missing owner and name for some reason" do
      let(:project) do
        FactoryBot.build(:project,
                         :repository => FactoryBot.build(:repository,
                                                         :owner => nil,
                                                         :name => nil,
                                                         :url => "git@github.com:styleket/libre-web-app.git"))
      end

      it "resorts to url parsing to compose it" do
        expect(project.repo_owner_and_name).to eql("styleket/libre-web-app")
      end
    end

    context "normal repo with owner and name" do
      let(:project) do
        FactoryBot.build(:project,
                         :repository => FactoryBot.build(:repository,
                                                         :owner => "renderedtext",
                                                         :name => "soc",
                                                         :url => "git@github.com:styleket/libre-web-app.git"))
      end

      it "uses repo owner and name" do
        expect(project.repo_owner_and_name).to eql("renderedtext/soc")
      end
    end
  end

  describe "#whitelist_branches" do
    context "whitelist on repository is nil" do
      let(:project) do
        FactoryBot.build(:project,
                         :repository => FactoryBot.build(:repository, :whitelist => nil))
      end

      it "returns empty array" do
        expect(project.whitelist_branches).to eql([])
      end
    end

    context "whitelist on repository has branches" do
      let(:project) do
        FactoryBot.build(:project,
                         :repository => FactoryBot.build(:repository, :whitelist => { "branches" => ["foo", "/foo/"] }))
      end

      it "returns empty array" do
        expect(project.whitelist_branches).to eql(["foo", "/foo/"])
      end
    end
  end

  describe "#whitelist_tags" do
    context "whitelist on repository is nil" do
      let(:project) do
        FactoryBot.build(:project,
                         :repository => FactoryBot.build(:repository, :whitelist => nil))
      end

      it "returns empty array" do
        expect(project.whitelist_tags).to eql([])
      end
    end

    context "whitelist on repository has tags" do
      let(:project) do
        FactoryBot.build(:project,
                         :repository => FactoryBot.build(:repository, :whitelist => { "tags" => ["foo", "/foo/"] }))
      end

      it "returns empty array" do
        expect(project.whitelist_tags).to eql(["foo", "/foo/"])
      end
    end
  end

end
