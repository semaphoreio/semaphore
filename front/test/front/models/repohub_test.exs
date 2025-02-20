defmodule Front.Models.RepohubTest do
  use Front.TestCase

  alias Front.Models.Repohub
  alias InternalApi.Repository.GetFilesRequest.Selector

  describe ".extract_selectors" do
    test "returns only init file when file is in the root" do
      assert Repohub.extract_selectors("semaphore.yml") == [Selector.new(glob: "semaphore.yml")]
    end

    test "returns only init file when file is hidden in the root" do
      assert Repohub.extract_selectors(".semaphore.yml") == [Selector.new(glob: ".semaphore.yml")]
    end

    test "returns only init file when file is in the root and prefixed with /" do
      assert Repohub.extract_selectors("/.semaphore.yml") == [
               Selector.new(glob: ".semaphore.yml")
             ]
    end

    test "returns only init file when file is in the root and prefixed with ./" do
      assert Repohub.extract_selectors("./.semaphore.yml") == [
               Selector.new(glob: ".semaphore.yml")
             ]
    end

    test "returns matching selectors if file is in direcotry" do
      assert Repohub.extract_selectors(".semaphore/semaphore.yml") == [
               Selector.new(glob: ".semaphore/**/*.yml"),
               Selector.new(glob: ".semaphore/**/*.yaml")
             ]
    end

    test "returns matching selectors if path starts with /" do
      assert Repohub.extract_selectors("/.semaphore/semaphore.yml") == [
               Selector.new(glob: ".semaphore/**/*.yml"),
               Selector.new(glob: ".semaphore/**/*.yaml")
             ]
    end

    test "returns matching selectors if path starts with ./" do
      assert Repohub.extract_selectors("./.semaphore/semaphore.yml") == [
               Selector.new(glob: ".semaphore/**/*.yml"),
               Selector.new(glob: ".semaphore/**/*.yaml")
             ]
    end

    test "returns matching selectors if file is in direcotry tree" do
      assert Repohub.extract_selectors("ci/semaphore/semaphore.yml") == [
               Selector.new(glob: "ci/semaphore/**/*.yml"),
               Selector.new(glob: "ci/semaphore/**/*.yaml")
             ]
    end
  end
end
