defmodule Front.Models.BranchTest do
  use Front.TestCase

  alias Front.Models.Branch

  describe ".find_by_id" do
    test "when branch => sets type as branch" do
      branch_response =
        InternalApi.Branch.DescribeResponse.new(
          status: Support.Factories.status_ok(),
          branch_id: "06278ef7-dcde-4d87-b405-ca39fb5f9827",
          branch_name: "master",
          project_id: "342841b2-11ff-4380-a215-2b038e07d8d7",
          tag_name: "",
          pr_name: "",
          pr_number: "",
          type: InternalApi.Branch.Branch.Type.value(:BRANCH)
        )

      GrpcMock.stub(BranchMock, :describe, branch_response)

      branch = Branch.find_by_id("06278ef7-dcde-4d87-b405-ca39fb5f9827")

      assert branch.type == "branch"
    end

    test "when tag => sets type as tag" do
      branch_response =
        InternalApi.Branch.DescribeResponse.new(
          status: Support.Factories.status_ok(),
          branch_id: "06278ef7-dcde-4d87-b405-ca39fb5f9827",
          branch_name: "master",
          project_id: "342841b2-11ff-4380-a215-2b038e07d8d7",
          tag_name: "v1.2.3",
          pr_name: "",
          pr_number: "",
          type: InternalApi.Branch.Branch.Type.value(:TAG)
        )

      GrpcMock.stub(BranchMock, :describe, branch_response)

      branch = Branch.find_by_id("06278ef7-dcde-4d87-b405-ca39fb5f9827")

      assert branch.type == "tag"
    end

    test "when PR => sets type as PR" do
      branch_response =
        InternalApi.Branch.DescribeResponse.new(
          status: Support.Factories.status_ok(),
          branch_id: "06278ef7-dcde-4d87-b405-ca39fb5f9827",
          branch_name: "master",
          project_id: "342841b2-11ff-4380-a215-2b038e07d8d7",
          tag_name: "",
          pr_name: "PR name",
          pr_number: "12",
          type: InternalApi.Branch.Branch.Type.value(:PR)
        )

      GrpcMock.stub(BranchMock, :describe, branch_response)

      branch = Branch.find_by_id("06278ef7-dcde-4d87-b405-ca39fb5f9827")

      assert branch.type == "pull-request"
    end
  end

  describe ".list" do
    test "when the response is succesfull => it returns a list of branch model instances" do
      project_id = "78114608-be8a-465a-b9cd-81970fb802c6"
      branches = [Support.Factories.branch()]

      branch_list_response =
        InternalApi.Branch.ListResponse.new(
          status: Support.Factories.status_ok(),
          branches: branches,
          page_number: 1,
          page_size: 10,
          total_entries: 12,
          total_pages: 30
        )

      GrpcMock.stub(BranchMock, :list, branch_list_response)

      assert Branch.list(project_id: project_id) ==
               {[
                  %Branch{
                    :name => "master",
                    :id => "78114608-be8a-465a-b9cd-81970fb802c6",
                    :project_id => "78114608-be8a-465a-b9cd-81970fb802c6",
                    :html_url => "/branches/78114608-be8a-465a-b9cd-81970fb802c6",
                    :pr_name => "",
                    :pr_number => "",
                    :tag_name => "",
                    :display_name => "master",
                    :type => "branch"
                  }
                ], 30}
    end

    test "when the response is unsuccesfull => it returns nil" do
      branch_list_response =
        InternalApi.Branch.ListResponse.new(status: Support.Factories.status_not_ok())

      GrpcMock.stub(BranchMock, :list, branch_list_response)

      assert Branch.list(project_id: "dasd-asd-asd-asd-as") == nil
    end
  end
end
