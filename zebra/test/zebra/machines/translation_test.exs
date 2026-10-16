defmodule Zebra.Machines.TranslationTest do
  use ExUnit.Case

  alias Zebra.Machines.Translation

  setup do
    Mox.stub_with(Support.MockedProvider, Support.StubbedProvider)
    :ok
  end

  describe ".map_machine" do
    test "maps e1 and e2 types and keeps the image" do
      assert Translation.map_machine("e1-standard-2", "img") == {"f1-standard-2", "img"}
      assert Translation.map_machine("e1-standard-4", "img") == {"f1-standard-2", "img"}
      assert Translation.map_machine("e1-standard-8", "img") == {"f1-standard-4", "img"}
      assert Translation.map_machine("e2-standard-2", "img") == {"f1-standard-2", "img"}
      assert Translation.map_machine("e2-standard-4", "img") == {"f1-standard-4", "img"}
    end

    test "keeps unknown types" do
      assert Translation.map_machine("e1-standard-16", "img") == {"e1-standard-16", "img"}
      assert Translation.map_machine("f1-standard-2", "img") == {"f1-standard-2", "img"}
    end
  end

  describe ".translate" do
    test "maps e1 types when the e1 flag is enabled" do
      org_id = Support.StubbedProvider.e1_to_f1_org_id()

      assert Translation.translate("e1-standard-8", "ubuntu2004", org_id) ==
               {"f1-standard-4", "ubuntu2004", true}
    end

    test "maps e2 types when the e2 flag is enabled" do
      org_id = Support.StubbedProvider.e2_to_f1_org_id()

      assert Translation.translate("e2-standard-2", "ubuntu2004", org_id) ==
               {"f1-standard-2", "ubuntu2004", true}
    end

    test "does not map a family whose flag is disabled for the org" do
      e2_org = Support.StubbedProvider.e2_to_f1_org_id()

      assert Translation.translate("e1-standard-2", "ubuntu2004", e2_org) ==
               {"e1-standard-2", "ubuntu2004", false}
    end

    test "marks a flagged family as translated even without a mapping" do
      org_id = Support.StubbedProvider.e1_to_f1_org_id()

      assert Translation.translate("e1-standard-16", "img", org_id) ==
               {"e1-standard-16", "img", true}
    end

    test "keeps the machine without an org" do
      assert Translation.translate("e1-standard-2", "img", nil) == {"e1-standard-2", "img", false}
    end

    test "coerces nil type and image" do
      assert Translation.translate(nil, nil, "any-org") == {"", "", false}
    end

    test "does not look up flags for other families" do
      Mox.stub(Support.MockedProvider, :provide_features, fn _, _ -> raise "unexpected lookup" end)

      assert Translation.translate("f1-standard-2", "img", "any-org") ==
               {"f1-standard-2", "img", false}

      assert Translation.translate("s1-my-agent", "", "any-org") == {"s1-my-agent", "", false}
    end
  end

  describe ".translatable?" do
    test "is true only for families that may be translated" do
      assert Translation.translatable?("e1-standard-2")
      assert Translation.translatable?("e2-standard-4")
      refute Translation.translatable?("f1-standard-2")
      refute Translation.translatable?("s1-e1-lookalike")
      refute Translation.translatable?(nil)
    end
  end
end
