defmodule Front.Layout.ModelTest do
  use Front.TestCase

  alias Front.Layout.Model
  alias Front.Layout.Model.LoadParams
  alias Support.Stubs

  describe ".load_from_api" do
    test "it completes without error" do
      user = Stubs.User.create_default()
      org = Stubs.Organization.create_default()

      params =
        struct!(LoadParams,
          user_id: user.id,
          organization_id: org.id
        )

      {:ok, _data, :from_api} = Model.load_from_api(params)
    end

    test "when the organization has suspensions => loads them" do
      alias InternalApi.Organization.Suspension

      user = Stubs.User.create_default()
      org = Stubs.Organization.create_default()

      Stubs.Organization.suspend(
        org,
        reason: Suspension.Reason.value(:VIOLATION_OF_TOS)
      )

      params =
        struct!(LoadParams,
          user_id: user.id,
          organization_id: org.id
        )

      {:ok, data, :from_api} = Model.load_from_api(params)

      assert data.suspensions == [:VIOLATION_OF_TOS]
    end
  end
end
