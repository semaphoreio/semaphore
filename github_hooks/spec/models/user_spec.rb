require "spec_helper"

RSpec.describe User, :type => :model do
  it { is_expected.to have_many(:repo_host_accounts).dependent(:destroy) }
end
