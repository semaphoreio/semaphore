defmodule RepositoryHub.BaseValidatorTest do
  use ExUnit.Case, async: true
  doctest RepositoryHub.BaseValidator, import: true

  describe "" do
    import RepositoryHub.BaseValidator, only: [select: 1]

    test ":inspect inspects a value" do
      import ExUnit.CaptureIO
      inspect = select(:inspect)

      io =
        capture_io(fn ->
          assert 100 = inspect.(100, [])
          assert 100 = inspect.(100, label: "With label")
        end)

      assert io == "inspect: 100\nWith label: 100\n"
    end

    test ":identity passes value through" do
      identity = select(:identity)
      assert 99 == identity.(99, [])
      assert 100 == identity.(100, [])
      assert 101 == identity.(101, [])

      assert 100 == identity.(101, 100), "can be used to inject values"
    end

    test ":eq checks if value is equal to an argument" do
      eq = select(:eq)
      assert {:error, _} = eq.(99, 100)
      assert 100 == eq.(100, 100)
      assert {:error, _} = eq.(101, 100)
    end

    test ":neq checks if value is not equal to an argument" do
      neq = select(:neq)
      assert 99 == neq.(99, 100)
      assert {:error, _} = neq.(100, 100)
      assert 101 == neq.(101, 100)
    end

    test ":lt checks if value is lesser than argument" do
      lt = select(:lt)
      assert 99 == lt.(99, 100)
      assert {:error, _} = lt.(100, 100)
      assert {:error, _} = lt.(101, 100)
    end

    test ":lte checks if value is lesser or equal to argument" do
      lte = select(:lte)
      assert 99 == lte.(99, 100)
      assert 100 == lte.(100, 100)
      assert {:error, _} = lte.(101, 100)
    end

    test ":gt checks if value is greater than argument" do
      gt = select(:gt)
      assert {:error, _} = gt.(99, 100)
      assert {:error, _} = gt.(100, 100)
      assert 101 == gt.(101, 100)
    end

    test ":gte checks if value is greater than or equal to value" do
      gte = select(:gte)
      assert {:error, _} = gte.(99, 100)
      assert 100 = gte.(100, 100)
      assert 101 == gte.(101, 100)
    end

    test ":length checks if value has length, and returns it if it does" do
      length = select(:length)
      assert 0 == length.([], [])
      assert 1 == length.([2], [])
      assert 3 == length.("1-1", [])
      assert 0 == length.("", [])
      assert {:error, _} = length.(100, [])
    end

    test ":all validates if all of the given validators passes" do
      all = select(:all)

      raiser = fn _ ->
        raise "I will raise."
      end

      divisible_by_3 = fn int ->
        rem(int, 3) == 0
      end

      validator = fn value, _opts ->
        divisible_by_3.(value)
        |> case do
          true -> value
          _ -> {:error, "is not divisible by 3"}
        end
      end

      assert {:error, _} = all.(98, [validator, gt: 98, lt: 101])
      assert 99 == all.(99, [validator, gt: 98, lt: 101])
      assert {:error, _} = all.(100, [validator, gt: 98, lt: 101])
      assert {:error, _} = all.(101, [validator, gt: 98, lt: 101])

      assert_raise RuntimeError, "I will raise.", fn ->
        {:error, _} = all.(101, [validator, {:gt, 98}, {:lt, 101}, &raiser.(&1)])
      end
    end

    test ":any validates if any of the given validators passes" do
      any = select(:any)
      assert 99 == any.(99, lt: 100, gt: 100)
      assert {:error, _} = any.(100, lt: 100, gt: 100)
      assert 101 == any.(101, lt: 100, gt: 100)
    end

    test ":is_map checks if value is a map" do
      is_map = select(:is_map)
      assert %{} == is_map.(%{}, [])
      assert %{a: 1} == is_map.(%{a: 1}, [])
      assert {:error, _} = is_map.([], [])
    end

    test ":from! fetches value by key(s) from map and returns it" do
      from! = select(:from!)

      assert 0 == from!.(%{counter: 0}, :counter)
      assert 1 == from!.(%{counter: 1}, :counter)
      assert {:error, _} = from!.(%{other_counter: 2}, :counter)
      assert {:error, _} = from!.(%{counter: 0}, :some_non_existent_key)

      user_data = %{user: %{id: "b01e81b6-1e48-443e-b625-f340977cd33a"}}
      assert %{id: "b01e81b6-1e48-443e-b625-f340977cd33a"} == from!.(user_data, :user)

      assert "b01e81b6-1e48-443e-b625-f340977cd33a" == from!.(user_data, [:user, :id])
      assert {:error, _} = from!.(user_data, [:user, :bar])
    end

    test ":is_integer checks if value is an integer" do
      is_integer = select(:is_integer)
      assert 1 == is_integer.(1, [])
      assert {:error, _} = is_integer.(1.2, [])
      assert 5 == is_integer.(0x5, [])
      assert 5 == is_integer.(05, [])
    end

    test ":is_string" do
      is_string = select(:is_string)
      assert {:error, _} = is_string.(1, [])
      assert "1" == is_string.("1", [])
    end

    test ":is_empty" do
      is_empty = select(:is_empty)
      assert [] == is_empty.([], [])
      assert %{} == is_empty.(%{}, [])
      assert {} == is_empty.({}, [])
      assert "" == is_empty.("", [])
      assert {:error, _} = is_empty.("", empty_values: [])
    end

    test ":is_not_empty" do
      is_not_empty = select(:is_not_empty)
      assert {:error, _} = is_not_empty.([], [])
      assert {:error, _} = is_not_empty.(%{}, [])
      assert {:error, _} = is_not_empty.({}, [])
      assert {:error, _} = is_not_empty.("", [])
      assert {:error, _} = is_not_empty.("empty", empty_values: ["empty"])
      assert "" = is_not_empty.("", empty_values: ["empty"])
    end

    test ":check runs a check function on value" do
      check = select(:check)
      assert true == check.(true, &is_boolean/1)
      assert {:error, _} = check.("true", &is_boolean/1)
      assert [] == check.([], &is_list/1)
      assert {:error, _} = check.(nil, &is_list/1)
      assert {:error, _} = check.(nil, fn -> raise "Can't stand it" end)
    end

    test ":is_github_url checks if a string is a valid github url" do
      is_github_url = select(:is_github_url)

      assertions = [
        {true, "github.com/foo/bar"},
        {true, "https://github.com/foo/bar.git"},
        {true, "https://github.com/shiroyasha/base-app.git"},
        {true, "ssh://git@github.com:/marvinwills/base-app.git"},
        {true, "git@github.com:marvinwills/base.app.com.git"},
        {true, "git@github.com:marvinwills/base.app.com.git"},
        {false, "https://bitbucket.org/shiroyasha/base-app.git"},
        {false, "ssh://git@bitbucket.org:/marvinwills/base-app.git"},
        {false, "github.com shiroyasha$$$base-app.git"},
        {false, "somehost.com/foo/bar"}
      ]

      for {true, url} <- assertions do
        assert(url == is_github_url.(url, []), "Expected #{url} to pass validation")
      end

      for {false, url} <- assertions do
        assert(match?({:error, _}, is_github_url.(url, [])), "Expected #{url} to fail validation")
      end
    end

    test ":is_bitbucket_url checks if a string is a valid bitbucket url" do
      is_bitbucket_url = select(:is_bitbucket_url)

      assertions = [
        {true, "bitbucket.org/foo/bar"},
        {true, "https://bitbucket.org/foo/bar.git"},
        {true, "https://bitbucket.org/shiroyasha/base-app.git"},
        {true, "ssh://git@bitbucket.org:/marvinwills/base-app.git"},
        {true, "git@bitbucket.org:marvinwills/base.app.com.git"},
        {true, "git@bitbucket.org:marvinwills/base.app.com.git"},
        {false, "https://github.com/shiroyasha/base-app.git"},
        {false, "ssh://git@github.com:/marvinwills/base-app.git"},
        {false, "bitbucket.org shiroyasha$$$base-app.git"},
        {false, "somehost.com/foo/bar"}
      ]

      for {true, url} <- assertions do
        assert(url == is_bitbucket_url.(url, []), "Expected #{url} to pass validation")
      end

      for {false, url} <- assertions do
        assert(match?({:error, _}, is_bitbucket_url.(url, [])), "Expected #{url} to fail validation")
      end
    end

    test ":take! fetches validation results and passes them through as a list" do
      take! = select(:take!)

      params = %{
        number_of_items: 10,
        item_price: 5,
        foo: 2
      }

      assert [10, 5] == take!.(params, from!: :number_of_items, from!: :item_price)
      assert {:error, _} = take!.(params, from!: :number_of_items, from!: :item_prices)
    end

    test ":chain enables constructing validation pipelines" do
      chain = select(:chain)

      assert 10 == chain.(10, gt: 2, gt: 3, gt: 9, lte: 10)
      assert 10 == chain.(10, gt: 2)

      assert {:error, "is not greater than 12"} == chain.(10, gt: 5, lt: 11, gt: 12)

      assert {:error, "is not greater than 13"} ==
               chain.(10, gt: 13, lt: 11, gt: 7, lt: 55, gt: 99)

      assert {:error, "custom error"} ==
               chain.(10, gt: 13, lt: 11, gt: 7, lt: 55, gt: 99, error_message: "custom error")

      assert {:error, "10 is not greater than 13"} ==
               chain.(10,
                 gt: 13,
                 lt: 11,
                 gt: 7,
                 lt: 55,
                 gt: 99,
                 error_message: fn error_message, value ->
                   "#{inspect(value)} #{error_message}"
                 end
               )
    end

    test ":is_sha check if value is a valid sha (hex)" do
      is_sha = select(:is_sha)
      assert "abc" == is_sha.("abc", [])
      assert {:error, _} = is_sha.("abcdefg", [])
      assert {:error, _} = is_sha.("g123", [])
      assert {:error, _} = is_sha.("-234", [])
    end

    test ":is_url check if value is a valid url" do
      is_url = select(:is_url)
      assert "abc" == is_url.("abc", [])
      assert "a/b/c/d/e" = is_url.("a/b/c/d/e", [])
      assert {:error, _} = is_url.("no whitespaces please", [])
    end

    test ":is_file_path check if value is a valid file path" do
      is_file_path = select(:is_file_path)
      assert "abc" == is_file_path.("abc", [])
      assert "a/b/c/d/e" = is_file_path.("a/b/c/d/e", [])
      assert {:error, _} = is_file_path.("", [])
    end

    test ":is_integration_type checks if values is a valid git provider" do
      is_integration_type = select(:is_integration_type)
      assert {:error, _} = is_integration_type.(-1, [])
      assert :GITHUB_OAUTH_TOKEN == is_integration_type.(:GITHUB_OAUTH_TOKEN, [])
      assert :GITHUB_APP == is_integration_type.(:GITHUB_APP, [])
      assert :BITBUCKET == is_integration_type.(:BITBUCKET, [])
      assert :GIT == is_integration_type.(:GIT, [])
      assert {:error, _} = is_integration_type.(:SOME_OTHER_TYPE, [])
    end

    test "selecting unknown validators fails" do
      assert_raise RuntimeError, "unknown validator :some_unknown_validator", fn ->
        select(:some_unknown_validator)
      end
    end
  end
end
