defmodule Scheduler.Periodics.Model.Periodics.Test do
  use ExUnit.Case
  doctest Scheduler.Periodics.Model.Periodics

  alias Scheduler.Periodics.Model.Periodics
  setup_all [:prepare_common_params]

  describe "changeset/2 with version v1.1" do
    test "when recurring is not given then validates as recurring", ctx do
      assert %Ecto.Changeset{valid?: false, errors: errors} =
               Periodics.changeset(%Periodics{}, "v1.1", ctx.params)

      assert [at: {"can't be blank", _}] = errors

      full_params =
        Map.merge(ctx.params, %{at: "* * * * *", branch: "master", pipeline_file: "deploy.yml"})

      assert %Ecto.Changeset{valid?: true} =
               Periodics.changeset(%Periodics{}, "v1.1", full_params)
    end

    test "when recurring is true then validates if periodics has cron, branch and pipeline file",
         ctx do
      partial_params =
        Map.merge(ctx.params, %{recurring: true}) |> Map.drop(~w(at branch pipeline_file)a)

      assert %Ecto.Changeset{valid?: false, errors: errors} =
               Periodics.changeset(%Periodics{}, "v1.1", partial_params)

      assert [:at, :branch, :pipeline_file] = errors |> Keyword.keys()

      assert ["can't be blank"] =
               errors |> Keyword.values() |> Enum.map(&elem(&1, 0)) |> Enum.uniq()

      full_params =
        Map.merge(partial_params, %{
          at: "* * * * *",
          branch: "master",
          pipeline_file: "deploy.yml"
        })

      assert %Ecto.Changeset{valid?: true} =
               Periodics.changeset(%Periodics{}, "v1.1", full_params)
    end

    test "when recurring is false then cron is not mandatory", ctx do
      assert %Ecto.Changeset{valid?: true} =
               Periodics.changeset(%Periodics{}, "v1.1", Map.put(ctx.params, :recurring, false))
    end

    test "when cron expression is invalid then invalid", ctx do
      params = Map.merge(ctx.params, %{branch: "master", pipeline_file: "deploy.yml"})

      invalid_params = Map.put(params, :at, "0 0 * * 12")

      assert %Ecto.Changeset{valid?: false, errors: [at: {"is not a valid cron expression", _}]} =
               Periodics.changeset(%Periodics{}, "v1.1", invalid_params)

      valid_params = Map.put(params, :at, "0 2 * 4,8 0-4")

      assert %Ecto.Changeset{valid?: true} =
               Periodics.changeset(%Periodics{}, "v1.1", valid_params)
    end
  end

  defp prepare_common_params(_ctx) do
    {:ok,
     params: %{
       requester_id: UUID.uuid4(),
       organization_id: UUID.uuid4(),
       name: "P1",
       project_name: "Pr1",
       project_id: "p1",
       branch: "master",
       pipeline_file: "deploy.yml",
       id: UUID.uuid1()
     }}
  end
end
