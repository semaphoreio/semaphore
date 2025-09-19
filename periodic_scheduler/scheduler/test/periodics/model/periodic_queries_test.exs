defmodule Scheduler.Periodics.Model.PeriodicsQueries.Test do
  use ExUnit.Case

  alias Scheduler.Periodics.Model.PeriodicsQueries
  alias Scheduler.Periodics.Model.PeriodicsParam

  setup do
    Test.Helpers.truncate_db()
    :ok
  end

  defp insert_periodics(params, nos, project_no) do
    for no <- nos do
      per_params = %{
        params
        | name: "Periodic_#{no |> Integer.to_string() |> String.pad_leading(2, "0")}",
          project_name: "Project_#{project_no}",
          project_id: "pr#{project_no}"
      }

      PeriodicsQueries.insert(per_params, "v1.1")
    end
  end

  describe "list/1" do
    setup do
      params = insert_params("v1.1")
      insert_periodics(params, 1..15, 1)
      insert_periodics(params, 20..1, 2)

      default_params = %{
        order: :BY_NAME_ASC,
        direction: :NEXT,
        page_size: 50,
        page: 1,
        organization_id: :skip,
        project_id: :skip,
        requester_id: :skip,
        query: :skip
      }

      {:ok, %{default_params: default_params}}
    end

    test "lists periodics by organization_id", ctx do
      assert {:ok, result} =
               PeriodicsQueries.list(%{ctx.default_params | organization_id: "org_1"})

      assert Enum.count(result.entries) == 35
    end

    test "lists periodics by project_id", ctx do
      assert {:ok, result} = PeriodicsQueries.list(%{ctx.default_params | project_id: "pr1"})
      assert Enum.count(result.entries) == 15

      assert {:ok, result} = PeriodicsQueries.list(%{ctx.default_params | project_id: "pr2"})
      assert Enum.count(result.entries) == 20
    end

    test "lists periodics by query string", ctx do
      assert {:ok, result} =
               PeriodicsQueries.list(%{ctx.default_params | project_id: "pr1", query: "1"})

      assert Enum.count(result.entries) == 7

      assert {:ok, result} =
               PeriodicsQueries.list(%{ctx.default_params | project_id: "pr2", query: "2"})

      assert Enum.count(result.entries) == 3
    end

    test "orders periodics by given order", ctx do
      assert {:ok, result} =
               PeriodicsQueries.list(%{
                 ctx.default_params
                 | project_id: "pr1",
                   order: :BY_NAME_ASC
               })

      assert Enum.at(result.entries, 0).name == "Periodic_01"
      assert Enum.at(result.entries, 14).name == "Periodic_15"

      assert {:ok, result} =
               PeriodicsQueries.list(%{
                 ctx.default_params
                 | project_id: "pr1",
                   order: :BY_CREATION_DATE_DESC
               })

      assert Enum.at(result.entries, 0).name == "Periodic_15"
      assert Enum.at(result.entries, 14).name == "Periodic_01"
    end

    test "paginates periodics", ctx do
      assert {:ok, result} =
               PeriodicsQueries.list(%{
                 ctx.default_params
                 | project_id: "pr1",
                   page_size: 10,
                   page: 1
               })

      assert Enum.count(result.entries) == 10
      assert result.total_entries == 15
      assert result.total_pages == 2
      assert result.page_number == 1
      assert result.page_size == 10

      assert {:ok, result} =
               PeriodicsQueries.list(%{
                 ctx.default_params
                 | project_id: "pr2",
                   page_size: 15,
                   page: 2
               })

      assert Enum.count(result.entries) == 5
      assert result.total_entries == 20
      assert result.total_pages == 2
      assert result.page_number == 2
      assert result.page_size == 15
    end
  end

  describe "list_keyset/1" do
    setup do
      params = insert_params("v1.1")
      insert_periodics(params, 1..15, 1)
      insert_periodics(params, 20..1, 2)

      default_params = %{
        order: :BY_NAME_ASC,
        direction: :NEXT,
        page_size: 50,
        page_token: nil,
        organization_id: :skip,
        project_id: :skip,
        requester_id: :skip,
        query: :skip
      }

      {:ok, %{default_params: default_params}}
    end

    test "lists periodics by organization_id", ctx do
      assert {:ok, result} =
               PeriodicsQueries.list_keyset(%{ctx.default_params | organization_id: "org_1"})

      assert Enum.count(result.entries) == 35
    end

    test "lists periodics by project_id", ctx do
      assert {:ok, result} =
               PeriodicsQueries.list_keyset(%{ctx.default_params | project_id: "pr1"})

      assert Enum.count(result.entries) == 15

      assert {:ok, result} =
               PeriodicsQueries.list_keyset(%{ctx.default_params | project_id: "pr2"})

      assert Enum.count(result.entries) == 20
    end

    test "lists periodics by query string", ctx do
      assert {:ok, result} =
               PeriodicsQueries.list_keyset(%{ctx.default_params | project_id: "pr1", query: "1"})

      assert Enum.count(result.entries) == 7

      assert {:ok, result} =
               PeriodicsQueries.list_keyset(%{ctx.default_params | project_id: "pr2", query: "2"})

      assert Enum.count(result.entries) == 3
    end

    test "orders periodics by given order", ctx do
      assert {:ok, result} =
               PeriodicsQueries.list_keyset(%{
                 ctx.default_params
                 | project_id: "pr1",
                   order: :BY_NAME_ASC
               })

      assert Enum.at(result.entries, 0).name == "Periodic_01"
      assert Enum.at(result.entries, 14).name == "Periodic_15"

      assert {:ok, result} =
               PeriodicsQueries.list_keyset(%{
                 ctx.default_params
                 | project_id: "pr1",
                   order: :BY_CREATION_DATE_DESC
               })

      assert Enum.at(result.entries, 0).name == "Periodic_15"
      assert Enum.at(result.entries, 14).name == "Periodic_01"
    end

    test "paginates periodics", ctx do
      assert {:ok, result} =
               PeriodicsQueries.list_keyset(%{
                 ctx.default_params
                 | project_id: "pr1",
                   page_size: 10
               })

      assert Enum.count(result.entries) == 10
      assert result.metadata.after
      refute result.metadata.before

      assert {:ok, result} =
               PeriodicsQueries.list_keyset(%{
                 ctx.default_params
                 | project_id: "pr1",
                   page_size: 10,
                   page_token: result.metadata.after
               })

      assert Enum.count(result.entries) == 5
      refute result.metadata.after
      assert result.metadata.before

      assert {:ok, result} =
               PeriodicsQueries.list_keyset(%{
                 ctx.default_params
                 | project_id: "pr1",
                   page_size: 10,
                   page_token: result.metadata.before,
                   direction: :PREV
               })

      assert Enum.count(result.entries) == 10
      assert result.metadata.after
      refute result.metadata.before
    end
  end

  test "insert new periodic - api version v1.0" do
    params = insert_params("v1.0")
    ts_before = NaiveDateTime.utc_now()

    assert {:ok, periodic} = PeriodicsQueries.insert(params, "v1.0")

    assert periodic.requester_id == params.requester_id
    assert periodic.organization_id == params.organization_id
    assert periodic.suspended == false
    assert periodic.name == params.name
    assert periodic.project_name == params.project_name
    assert periodic.project_id == params.project_id
    assert periodic.reference == "refs/heads/#{params.reference}"
    assert periodic.at == params.at
    assert periodic.pipeline_file == params.pipeline_file
    assert NaiveDateTime.compare(ts_before, periodic.inserted_at) == :lt
  end

  test "insert new periodic - api version v1.1" do
    params = insert_params("v1.1")
    ts_before = NaiveDateTime.utc_now()

    assert {:ok, periodic} = PeriodicsQueries.insert(params, "v1.1")

    assert periodic.requester_id == params.requester_id
    assert periodic.organization_id == params.organization_id
    assert periodic.suspended == false
    assert periodic.name == params.name
    assert periodic.project_name == params.project_name
    assert periodic.project_id == params.project_id
    assert periodic.reference == "refs/heads/#{params.reference}"
    assert periodic.pipeline_file == params.pipeline_file
    refute periodic.at

    assert periodic.parameters == [
             %PeriodicsParam{name: "foo", required: true, default_value: "bar", options: []},
             %PeriodicsParam{
               name: "boo",
               required: false,
               default_value: nil,
               options: ["a", "b", "c"]
             }
           ]

    assert NaiveDateTime.compare(ts_before, periodic.inserted_at) == :lt
  end

  defp insert_params(_api_version = "v1.0") do
    %{
      requester_id: "usr_1",
      organization_id: "org_1",
      name: "Periodic_1",
      project_name: "Project_1",
      project_id: "pr1",
      reference: "master",
      at: "* * * * *",
      pipeline_file: "deploy.yml"
    }
  end

  defp insert_params(_api_version = "v1.1") do
    %{
      requester_id: "usr_1",
      organization_id: "org_1",
      name: "Periodic_1",
      project_name: "Project_1",
      project_id: "pr1",
      recurring: false,
      reference: "master",
      at: "",
      pipeline_file: "deploy.yml",
      parameters: [
        %{name: "foo", required: true, default_value: "bar"},
        %{name: "boo", required: false, options: ["a", "b", "c"]}
      ]
    }
  end

  test "can not insert periodic without required fileds" do
    params = insert_params("v1.0")

    params
    |> Map.keys()
    |> Enum.map(fn field_name ->
      params_ = params |> Map.delete(field_name)

      assert {:error, msg} = PeriodicsQueries.insert(params_, "v1.0")
      error_msg_1 = "errors: [#{field_name}: {\"can't be blank\", [validation: :required]}]"
      error_msg_2 = "The '#{field_name}' parameter can not be empty string."

      assert String.contains?("#{inspect(msg)}", error_msg_1) or
               String.contains?("#{inspect(msg)}", error_msg_2)
    end)
  end

  describe "insert/2 validation" do
    for field <-
          ~w(requester_id organization_id name project_name project_id reference pipeline_file)a do
      test "returns error when #{field} is missing" do
        params = insert_params("v1.1")
        params_ = params |> Map.delete(unquote(field))

        assert {:error, msg} = PeriodicsQueries.insert(params_, "v1.1")
        error_msg_1 = "errors: [#{unquote(field)}: {\"can't be blank\", [validation: :required]}]"
        error_msg_2 = "The '#{unquote(field)}' parameter can not be empty string."

        assert String.contains?("#{inspect(msg)}", error_msg_1) or
                 String.contains?("#{inspect(msg)}", error_msg_2)
      end
    end

    test "can insert periodic without at field" do
      params = insert_params("v1.1")
      params_ = params |> Map.delete(:at) |> Map.put(:name, "Periodic without at")

      assert {:ok, _periodic} = PeriodicsQueries.insert(params_, "v1.1")
    end
  end

  test "can not insert two periodics with same name for same project" do
    params1 = insert_params("v1.0")
    params2 = insert_params("v1.1")

    assert {:ok, _periodic} = PeriodicsQueries.insert(params1, "v1.0")
    assert {:error, message} = PeriodicsQueries.insert(params2, "v1.1")

    assert message ==
             "Periodic with name 'Periodic_1' already exists for project 'Project_1'."
  end

  test "update periodic data" do
    params = insert_params("v1.0")
    assert {:ok, periodic_1} = PeriodicsQueries.insert(params, "v1.0")

    params_2 = params |> Map.merge(%{reference: "dev", at: "@yearly"})
    assert {:ok, periodic_2} = PeriodicsQueries.update(periodic_1, params_2, "v1.0")

    assert periodic_2.reference == "refs/heads/dev"
    assert periodic_2.at == "@yearly"

    assert periodic_1 |> Map.drop([:updated_at, :reference, :at]) ==
             periodic_2 |> Map.drop([:updated_at, :reference, :at])
  end

  test "cannot update periodics to the existing name for same project" do
    params_1 = insert_params("v1.0") |> Map.merge(%{name: "Periodic_1"})
    params_2 = insert_params("v1.0") |> Map.merge(%{name: "Periodic_2"})

    assert {:ok, _periodic_1} = PeriodicsQueries.insert(params_1, "v1.0")
    assert {:ok, periodic_2} = PeriodicsQueries.insert(params_2, "v1.0")
    assert {:error, message} = PeriodicsQueries.update(periodic_2, params_1, "v1.0")

    assert message ==
             "Periodic with name 'Periodic_1' already exists for project 'Project_1'."
  end

  test "suspend periodic" do
    params = insert_params("v1.0")

    assert {:ok, periodic} = PeriodicsQueries.insert(params, "v1.0")
    assert periodic.suspended == false
    original_updated_at = periodic.updated_at

    assert {:ok, periodic} = PeriodicsQueries.suspend(periodic)
    assert periodic.suspended == true
    assert original_updated_at == periodic.updated_at
  end

  test "pause/unpause periodic" do
    params = insert_params("v1.0")

    assert {:ok, periodic} = PeriodicsQueries.insert(params, "v1.0")
    assert periodic.paused == false
    assert periodic.pause_toggled_by == ""
    assert periodic.pause_toggled_at == nil
    original_updated_at = periodic.updated_at

    assert {:ok, periodic} = PeriodicsQueries.pause(periodic, "user_1")
    assert periodic.paused == true
    assert periodic.pause_toggled_by == "user_1"
    assert :lt == DateTime.compare(periodic.pause_toggled_at, DateTime.utc_now())
    assert original_updated_at == periodic.updated_at

    assert {:ok, periodic} = PeriodicsQueries.unpause(periodic, "user_2")
    assert periodic.paused == false
    assert periodic.pause_toggled_by == "user_2"
    assert :lt == DateTime.compare(periodic.pause_toggled_at, DateTime.utc_now())
    assert original_updated_at == periodic.updated_at

    assert {:ok, periodic} = PeriodicsQueries.pause(periodic, "user_3")
    assert periodic.paused == true
    assert periodic.pause_toggled_by == "user_3"
    assert :lt == DateTime.compare(periodic.pause_toggled_at, DateTime.utc_now())
    assert original_updated_at == periodic.updated_at
  end

  test "get_by_id succeds for valid id" do
    params = insert_params("v1.0")

    assert {:ok, periodic_1} = PeriodicsQueries.insert(params, "v1.0")

    assert {:ok, periodic_1} == PeriodicsQueries.get_by_id(periodic_1.id)
  end

  test "get_by_id returns error when periodic with given id does not exist" do
    id = UUID.uuid4()
    assert {:error, msg} = PeriodicsQueries.get_by_id(id)
    assert msg == "Periodic with id: '#{id}' not found."
  end
end
