defmodule Guard.OrganizationCleanerTestTest do
  use Guard.RepoCase

  alias Guard.FrontRepo

  describe "process/1" do
    test "deletes organization when it exists" do
      FrontRepo.delete_all(FrontRepo.Organization)

      non_deleted_org_ids =
        1..3
        |> Enum.map(fn _ ->
          org = Support.Factories.Organization.insert!(username: gen_username())
          org.id
        end)

      _long_time_deleted_org_ids =
        1..3
        |> Enum.map(fn _ ->
          org =
            Support.Factories.Organization.insert!(
              username: gen_username(),
              deleted_at: datetime_by_days_ago(31)
            )

          org.id
        end)

      recent_deleted_org_ids =
        1..3
        |> Enum.map(fn _ ->
          org =
            Support.Factories.Organization.insert!(
              username: gen_username(),
              deleted_at: datetime_by_days_ago(1)
            )

          org.id
        end)

      Guard.OrganizationCleaner.process()

      all_org_ids =
        FrontRepo.Organization
        |> FrontRepo.all()
        |> Enum.map(fn org -> org.id end)
        |> MapSet.new()

      assert MapSet.new(non_deleted_org_ids ++ recent_deleted_org_ids)
             |> MapSet.equal?(all_org_ids)
    end
  end

  defp datetime_by_days_ago(days_ago) do
    DateTime.utc_now()
    |> DateTime.add(-days_ago * 24 * 60 * 60)
    |> DateTime.truncate(:second)
  end

  defp gen_username do
    Ecto.UUID.generate() |> String.replace("-", "")
  end
end
