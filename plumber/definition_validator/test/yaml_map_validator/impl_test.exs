defmodule DefinitionValidator.YamlMapValidator.Impl.Test do
  use ExUnit.Case
  doctest DefinitionValidator.YamlMapValidator.Impl

  alias DefinitionValidator.YamlMapValidator.Impl

  test "cache new schema" do
      version = "v1"
      spec = %{value: 123}
      assert {:ok, new_schemas} = cache_schema(%{}, version, spec)
      assert new_schemas == %{version => spec}
  end

  test "cache existing schema" do
    version = "v1"
    spec = %{value: 123}
    schemas = %{version => spec, foo: %{}}
    assert {:ok, new_schemas} = cache_schema(schemas, version, spec)
    assert new_schemas == schemas
  end

  test "caching invalid schema version" do
    schemas = %{}
    version = "wrong"
    error = {:error, :wrong_version}
    spec_getter = fn _ -> error end
    assert error == Impl.cache_schema(schemas, version, spec_getter)
  end

  defp cache_schema(schemas, version, spec) do
    spec_getter = fn _ -> {:ok, spec} end
    Impl.cache_schema(schemas, version, spec_getter)
  end

  test "validate without 'version' attribute in definition" do
    assert {:error, {:malformed, reason}} = Impl.validate(%{}, %{}, nil) |> get_response()
    assert String.contains?(reason, "version")
  end

  test "validate without schema" do
    ppl = %{"version" => "v1.0"}
    schemas = %{}
    assert {:noreply, response} = Impl.validate(ppl, schemas, nil)
    assert response == schemas
  end

  test "validate with minimal schema" do
    ppl = %{"version" => "v1.0"}
    schemas = %{"v1.0" => %{"$schema" => "http://json-schema.org/draft-04/schema#",
      "properties" => %{"version" => %{"type" => "string"}}}}
    assert {:ok, response} = Impl.validate(ppl, schemas, nil) |> get_response()
    assert ppl == response
  end

  defp get_response({:reply, response, _state}), do: response
end
