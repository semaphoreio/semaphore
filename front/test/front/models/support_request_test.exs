defmodule Front.Models.SupportRequestTest do
  use ExUnit.Case

  alias Front.Models.SupportRequest, as: Subject

  @support_form_params %{
    plan: "paid",
    segment: "iron",
    body: "ddd",
    provided_link: "https:dddd",
    subject: "Real subject",
    tags: ["urgent"],
    topic: "Feature Request",
    file_data: "iVBORw0KGgoAAAANSUhEUgAAAhgAAAL",
    file_name: "balinese-yawn.png",
    file_size: 974_819,
    file_type: "image/png"
  }

  setup do
    Support.FakeServices.stub_responses()
  end

  describe ".changeset" do
    test "every request includes 2.0-support tag" do
      changeset = Subject.changeset(@support_form_params)

      assert Enum.member?(changeset.changes.tags, "2.0-support")
    end

    test "when billing data is available, changeset includes a tag defined by org plan" do
      tags = Subject.changeset(@support_form_params).changes.tags

      assert Enum.member?(tags, "paid")
    end

    test "includes the segment tag" do
      tags = Subject.changeset(@support_form_params).changes.tags

      assert Enum.member?(tags, "iron")
    end

    test "when plan is not valid and segment not defined, has proper tags" do
      input_params = %{
        plan: :error,
        segment: nil,
        body: "ddd",
        provided_link: "https:dddd",
        subject: "Real subject",
        tags: ["urgent"],
        topic: "Feature Request",
        file_data: "iVBORw0KGgoAAAANSUhEUgAAAhgAAAL",
        file_name: "balinese-yawn.png",
        file_size: 974_819,
        file_type: "image/png"
      }

      tags = Subject.changeset(input_params).changes.tags

      assert Enum.member?(tags, "failed-to-set-plan")
      refute Enum.member?(tags, "iron")
      refute Enum.member?(tags, "silver")
      refute Enum.member?(tags, "gold")
    end
  end
end
