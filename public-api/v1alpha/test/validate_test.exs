defmodule PipelinesAPI.Util.VerifyData.Test do
  use ExUnit.Case

  alias PipelinesAPI.Util.VerifyData, as: VD

  test "is_valid_uuid? function validates whether a string is valid uuid" do
    assert VD.is_valid_uuid?([]) == false
    assert VD.is_valid_uuid?("") == false
    assert VD.is_valid_uuid?("test") == false
    assert VD.is_valid_uuid?(UUID.uuid4()) == true
  end

  test "is_present_string? function returns true only when given a non-empty string" do
    assert VD.is_present_string?(nil) == false
    assert VD.is_present_string?([]) == false
    assert VD.is_present_string?("") == false
    assert VD.is_present_string?("test") == true
  end

  test "is_string_length? function validates length of the string" do
    assert VD.is_string_length?(nil, 1, 3, true) == false
    assert VD.is_string_length?(nil, 1, 3, false) == true

    assert VD.is_string_length?("", 1, 3, true) == false
    assert VD.is_string_length?("", 1, 3, false) == false

    assert VD.is_string_length?("1", 1, 3, true) == true
    assert VD.is_string_length?("1", 1, 3, false) == true

    assert VD.is_string_length?("12", 1, 3, true) == true
    assert VD.is_string_length?("12", 1, 3, false) == true

    assert VD.is_string_length?("123", 1, 3, true) == true
    assert VD.is_string_length?("123", 1, 3, false) == true

    assert VD.is_string_length?("1234", 1, 3, true) == false
    assert VD.is_string_length?("1234", 1, 3, false) == false

    assert VD.is_string_length?([], 1, 3, true) == false
    assert VD.is_string_length?([], 1, 3, false) == false
  end

  test "non_empty_list? function returns true only when given a non-empty list" do
    assert VD.non_empty_list?(nil) == false
    assert VD.non_empty_list?("") == false
    assert VD.non_empty_list?(%{a: ""}) == false
    assert VD.non_empty_list?([]) == false
    assert VD.non_empty_list?([""]) == true
    assert VD.non_empty_list?([1, 2]) == true
  end
end
