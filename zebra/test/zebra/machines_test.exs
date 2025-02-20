defmodule Zebra.MachinesTest do
  use Zebra.DataCase

  describe "mac?" do
    test "returns true for mac machine types" do
      assert Zebra.Machines.mac?("a1-standard-4")
    end

    test "returns false for non-mac machine types" do
      refute Zebra.Machines.mac?("e1-standard-4")
    end
  end

  describe "linux?" do
    test "returns true for linux machine types" do
      assert Zebra.Machines.linux?("e1-standard-4")
    end

    test "returns false for non-linux machine types" do
      refute Zebra.Machines.linux?("a1-standard-4")
    end
  end

  test "os_images returns list of all os images" do
    assert Zebra.Machines.os_images() == [
             "macos-xcode13",
             "macos-xcode14",
             "ubuntu1804",
             "ubuntu2004",
             "ubuntu2204"
           ]
  end

  test "linux_machine_types returns list of all linux machine types" do
    assert Zebra.Machines.linux_machine_types() == [
             "c1-standard-1",
             "e1-standard-2",
             "e1-standard-4",
             "e1-standard-8",
             "e2-standard-2",
             "e2-standard-4",
             "f1-standard-2",
             "f1-standard-4",
             "g1-standard-2",
             "g1-standard-3",
             "g1-standard-4"
           ]
  end

  test "mac_machine_types returns list of all mac machine types" do
    assert Zebra.Machines.mac_machine_types() == [
             "a1-standard-4",
             "a1-standard-8",
             "ax1-standard-4"
           ]
  end

  test "machine_types returns list of all machine types" do
    assert Zebra.Machines.machine_types() == [
             "a1-standard-4",
             "a1-standard-8",
             "ax1-standard-4",
             "c1-standard-1",
             "e1-standard-2",
             "e1-standard-4",
             "e1-standard-8",
             "e2-standard-2",
             "e2-standard-4",
             "f1-standard-2",
             "f1-standard-4",
             "g1-standard-2",
             "g1-standard-3",
             "g1-standard-4"
           ]
  end

  describe "registered?" do
    test "returns true for registered machines" do
      assert Zebra.Machines.registered?("e1-standard-4", "ubuntu1804")
      assert Zebra.Machines.registered?("e1-standard-4", "ubuntu2004")
      assert Zebra.Machines.registered?("a1-standard-4", "macos-xcode13")
    end

    test "returns false for not registered machines" do
      refute Zebra.Machines.registered?("e1-standard-4", "")
      refute Zebra.Machines.registered?("a1-standard-4", "ubuntu1804")
      refute Zebra.Machines.registered?("x1-standard-1", "macos-xcode11")
      refute Zebra.Machines.registered?("x1-standard-4", "macos-xcode11")
      refute Zebra.Machines.registered?("a1-standard-4", "macos-xcode12")
    end
  end

  describe "default_os_image" do
    test "known machine_type => returns the default image" do
      assert Zebra.Machines.default_os_image("e1-standard-4") ==
               {:ok, "ubuntu1804"}

      assert Zebra.Machines.default_os_image("a1-standard-4") ==
               {:ok, "macos-xcode13"}
    end

    test "unknown machine_type => returns error" do
      assert Zebra.Machines.default_os_image("x1-standard-4") ==
               {:error, "unknown machine type"}
    end
  end
end
