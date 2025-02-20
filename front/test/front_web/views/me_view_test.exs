defmodule FrontWeb.MeViewTest do
  use FrontWeb.ConnCase
  alias FrontWeb.MeView

  describe ".username_already_taken?" do
    test "when username contains already taken error => returns true" do
      errors = %{"username" => ["Already taken"], "name" => ["can't be blank"]}

      assert MeView.username_already_taken?(errors)
    end

    test "when username contains another error => it returns a falsey value" do
      errors = %{
        "username" => ["Use only letters a-z, numbers 0-9 and dash, no spaces."],
        "name" => ["can't be blank"]
      }

      refute MeView.username_already_taken?(errors)
    end

    test "when username has no errors => it returns a falsey value" do
      errors = %{"name" => ["can't be blank"]}

      refute MeView.username_already_taken?(errors)
    end

    test "when there are no errors => it returns a falsey value" do
      errors = nil

      refute MeView.username_already_taken?(errors)
    end
  end

  describe "other_username_error?" do
    test "when username contains wrong format error => it returns true" do
      errors = %{
        "username" => ["Use only letters a-z, numbers 0-9 and dash, no spaces."],
        "name" => ["can't be blank"]
      }

      assert MeView.other_username_error?(errors)
    end

    test "when username contains blank error => it returns true" do
      errors = %{"username" => ["can't be blank"], "name" => ["can't be blank"]}

      assert MeView.other_username_error?(errors)
    end

    test "when username contains taken error => it returns a falsey value" do
      errors = %{"username" => ["Already taken"], "name" => ["can't be blank"]}

      refute MeView.other_username_error?(errors)
    end

    test "when username has no errors => it returns a falsey value" do
      errors = %{"name" => ["can't be blank"]}

      refute MeView.other_username_error?(errors)
    end

    test "when there are no errors => it returns a falsey value" do
      errors = nil

      refute MeView.other_username_error?(errors)
    end
  end

  describe "name_missing?" do
    test "when name is missing  => it returns true" do
      errors = %{"username" => ["Already taken"], "name" => ["Cannot be empty"]}

      assert MeView.name_missing?(errors)
    end

    test "when name has no errors => it returns a falsey value" do
      errors = %{"username" => ["Cannot be empty"]}

      refute MeView.name_missing?(errors)
    end

    test "when there are no errors => it returns a falsey value" do
      errors = nil

      refute MeView.name_missing?(errors)
    end
  end
end
