/**
 * @prettier
 */

import { expect } from "chai";
import { Switch } from "./switch";
import { TargetParams } from "./target_params";
import { Utils } from "../utils";
import $ from "jquery";
import sinon from "sinon";

describe("Switch", () => {
  beforeEach(() => {
    // Setup DOM for tests
    document.body.innerHTML = `
      <div>
        <button promote-button data-switch="switch-123" data-promotion-target="Test Target"></button>
        <div promotion-box data-promotion-target="Test Target">
          <div promote-confirmation hidden>Confirm?</div>
          <button promote-button data-promotion-target="Test Target" data-switch="switch-123">Promote</button>
        </div>
        <div trigger-event data-switch="switch-123" data-promotion-target="Test Target"></div>
      </div>
    `;
  });

  afterEach(() => {
    sinon.restore();
    document.querySelectorAll("select").forEach((element) => {
      if (element.tomselect) {
        element.tomselect.destroy();
      }
    });
    document.body.innerHTML = "";
    $("body").off(); // Clean up event handlers
  });

  describe("promotion target name escaping", () => {
    it("handles promotion targets with single quotes", () => {
      const promotionName = "Publish 'my-package' to Production";
      const escaped = Utils.escapeCSSAttributeValue(promotionName);
      const expected = "Publish \\'my-package\\' to Production";

      expect(escaped).to.equal(expected);
      expect(() => {
        $(`[data-promotion-target="${escaped}"]`);
      }).to.not.throw();
    });

    it("handles promotion targets with double quotes", () => {
      const promotionName = 'Deploy "production" build';
      const escaped = Utils.escapeCSSAttributeValue(promotionName);
      const expected = 'Deploy \\"production\\" build';

      expect(escaped).to.equal(expected);
      expect(() => {
        $(`[data-promotion-target="${escaped}"]`);
      }).to.not.throw();
    });

    it("handles promotion targets with complex special characters", () => {
      const promotionName = "test'][arbitrary-selector][data-x='some-value";
      const escaped = Utils.escapeCSSAttributeValue(promotionName);
      const expected = "test\\'][arbitrary-selector][data-x=\\'some-value";

      expect(escaped).to.equal(expected);
      expect(() => {
        $(`[switch='123'] [data-promotion-target='${escaped}'][promote-button]`);
      }).to.not.throw();
    });

    it("handles promotion targets with brackets and colons", () => {
      const promotionName = "test[data]:value.class#id";
      const escaped = Utils.escapeCSSAttributeValue(promotionName);

      // CSS.escape handles these when available, fallback doesn't need to
      if (typeof CSS !== 'undefined' && CSS.escape) {
        expect(escaped).to.not.equal(promotionName);
      } else {
        expect(escaped).to.equal(promotionName);
      }
    });

    it("handles promotion targets with emoji", () => {
      const promotionName = "Deploy 🚀 to Production";
      const escaped = Utils.escapeCSSAttributeValue(promotionName);

      expect(escaped).to.equal(promotionName);
    });

    it("handles promotion targets with accented characters", () => {
      const promotionName = "Déploiement Français";
      const escaped = Utils.escapeCSSAttributeValue(promotionName);

      expect(escaped).to.equal(promotionName);
    });

    it("handles promotion targets with CJK characters", () => {
      const promotionName = "部署到生产环境";
      const escaped = Utils.escapeCSSAttributeValue(promotionName);

      expect(escaped).to.equal(promotionName);
    });

    it("handles mixed unicode and quotes", () => {
      const promotionName = "Deploy 'app' 🎉 to Staging";
      const escaped = Utils.escapeCSSAttributeValue(promotionName);
      const expected = "Deploy \\'app\\' 🎉 to Staging";

      expect(escaped).to.equal(expected);
    });
  });

  describe("hidePromotionBoxElements", () => {
    it("escapes promotion target before using in selector", () => {
      const promotionTarget = "Deploy 'prod' build";
      document.body.innerHTML = `
        <div switch="switch-1">
          <div promotion-box data-promotion-target="Deploy 'prod' build">
            <div class="child">Child element</div>
          </div>
        </div>
      `;

      Switch.hidePromotionBoxElements("switch-1", promotionTarget);

      // The child should be hidden (display: none)
      const child = $("[switch='switch-1'] [promotion-box] .child");
      expect(child.css("display")).to.equal("none");
    });
  });

  describe("askToConfirmPromotion", () => {
    it("escapes promotion target and shows confirmation", () => {
      const promotionTarget = "Test 'target' name";
      const escapedTarget = Utils.escapeCSSAttributeValue(promotionTarget);
      document.body.innerHTML = `
        <div switch="switch-1">
          <div promotion-box data-promotion-target="Test 'target' name">
            <div>Element</div>
          </div>
          <div promote-confirmation data-promotion-target="Test 'target' name" hidden>Confirm</div>
        </div>
      `;

      sinon.stub(Switch, "hidePromotionBoxElements");

      Switch.askToConfirmPromotion("switch-1", promotionTarget);

      // Verify hidePromotionBoxElements was called
      expect(Switch.hidePromotionBoxElements.calledOnce).to.be.true;

      // The confirmation element should have show() called (display not 'none')
      const confirmation = $(`[switch='switch-1'] [promote-confirmation][data-promotion-target='${escapedTarget}']`);
      expect(confirmation.css("display")).to.not.equal("none");

      Switch.hidePromotionBoxElements.restore();
    });
  });

  describe("showPromotingInProgress", () => {
    it("safely handles escaped promotion targets", () => {
      const promotionTarget = "Deploy \"staging\"";
      const escapedTarget = Utils.escapeCSSAttributeValue(promotionTarget);
      document.body.innerHTML = `
        <div switch="switch-1">
          <div promote-confirmation data-promotion-target='Deploy "staging"'>Confirm</div>
          <button promote-button data-promotion-target='Deploy "staging"'>Promote</button>
        </div>
      `;

      Switch.showPromotingInProgress("switch-1", promotionTarget);

      const confirmation = $(`[switch='switch-1'] [promote-confirmation][data-promotion-target='${escapedTarget}']`);
      const button = $(`[switch='switch-1'] [promote-button][data-promotion-target='${escapedTarget}']`);

      expect(confirmation.css("display")).to.equal("none");
      expect(button.css("display")).to.not.equal("none");
      expect(button.prop("disabled")).to.be.true;
      expect(button.hasClass("btn-working")).to.be.true;
    });
  });

  describe("handlePromoteClicks", () => {
    it("focuses the first promotion dropdown without scrolling", () => {
      document.body.innerHTML = `
        <div switch="switch-123">
          <div promotion-box data-promotion-target="Test Target">
            <button promote-button data-promotion-target="Test Target" data-switch="switch-123">Promote</button>
            <form hidden data-promotion-target="Test Target" promote-confirmation>
              <select name="parameters[environment]" data-promotion-param-name="environment">
                <option value="production">production</option>
              </select>
            </form>
          </div>
        </div>
      `;

      const focusStub = sinon.stub(HTMLElement.prototype, "focus");

      Switch.handlePromoteClicks();
      $("[promote-button]").trigger("click");

      const select = document.querySelector("[data-promotion-param-name]");
      const controlFocusCall = focusStub.getCalls().find((call) => {
        return call.thisValue === select.tomselect.control;
      });

      expect(select.tomselect).to.not.be.undefined;
      expect(controlFocusCall).to.not.be.undefined;
      expect(controlFocusCall.args[0]).to.deep.equal({ preventScroll: true });

      focusStub.restore();
    });

    it("focuses the first promotion text input without scrolling and keeps cursor placement", () => {
      document.body.innerHTML = `
        <div switch="switch-123">
          <div promotion-box data-promotion-target="Test Target">
            <button promote-button data-promotion-target="Test Target" data-switch="switch-123">Promote</button>
            <form hidden data-promotion-target="Test Target" promote-confirmation>
              <input name="parameters[environment]" value="production">
            </form>
          </div>
        </div>
      `;

      const input = document.querySelector("input");
      const focusStub = sinon.stub(HTMLElement.prototype, "focus");
      const selectionStub = sinon.stub(input, "setSelectionRange");

      Switch.handlePromoteClicks();
      $("[promote-button]").trigger("click");

      const inputFocusCall = focusStub.getCalls().find((call) => {
        return call.thisValue === input;
      });

      expect(inputFocusCall).to.not.be.undefined;
      expect(inputFocusCall.args[0]).to.deep.equal({ preventScroll: true });
      expect(selectionStub.calledOnceWith(input.value.length, input.value.length)).to.be.true;

      selectionStub.restore();
      focusStub.restore();
    });

    it("shows the promotion form without focus errors when there are no inputs", () => {
      document.body.innerHTML = `
        <div switch="switch-123">
          <div promotion-box data-promotion-target="Test Target">
            <button promote-button data-promotion-target="Test Target" data-switch="switch-123">Promote</button>
            <form hidden data-promotion-target="Test Target" promote-confirmation></form>
          </div>
        </div>
      `;

      const focusStub = sinon.stub(HTMLElement.prototype, "focus");

      Switch.handlePromoteClicks();
      expect(() => {
        $("[promote-button]").trigger("click");
      }).to.not.throw();
      expect(focusStub.notCalled).to.be.true;

      focusStub.restore();
    });
  });

  describe("TargetParams", () => {
    it("focuses TomSelect's focus node without scrolling", () => {
      document.body.innerHTML = `
        <select data-promotion-param-name="environment">
          <option value="production">production</option>
        </select>
      `;

      const focusStub = sinon.stub(HTMLElement.prototype, "focus");

      TargetParams.init("[data-promotion-param-name]");

      const select = document.querySelector("[data-promotion-param-name]");
      const focusNode = select.tomselect.focus_node;
      focusNode.focus();

      const focusNodeCall = focusStub.getCalls().find((call) => {
        return call.thisValue === focusNode && call.args[0] && call.args[0].preventScroll === true;
      });

      expect(focusNodeCall).to.not.be.undefined;
      expect(focusNodeCall.args[0]).to.deep.equal({ preventScroll: true });

      focusStub.restore();
    });

    it("does not reinitialize or double-wrap TomSelect on repeat init", () => {
      document.body.innerHTML = `
        <select data-promotion-param-name="environment">
          <option value="production">production</option>
        </select>
      `;

      TargetParams.init("[data-promotion-param-name]");

      const select = document.querySelector("[data-promotion-param-name]");
      const tomselect = select.tomselect;
      const wrappedFocus = tomselect.focus_node.focus;

      TargetParams.init("[data-promotion-param-name]");

      expect(select.tomselect).to.equal(tomselect);
      expect(tomselect.focus_node.focus).to.equal(wrappedFocus);
    });
  });

  describe("latestTriggerEvent", () => {
    it("finds trigger event with escaped promotion target", () => {
      const promotionTarget = "Deploy 'production'";
      document.body.innerHTML = `
        <div switch="switch-1">
          <div trigger-event data-promotion-target="Deploy 'production'" data-id="event-1">Event 1</div>
          <div trigger-event data-promotion-target="Deploy 'production'" data-id="event-2">Event 2</div>
        </div>
      `;

      const result = Switch.latestTriggerEvent("switch-1", promotionTarget);

      expect(result.length).to.equal(1);
      expect(result.attr("data-id")).to.equal("event-1");
    });
  });

  describe("parentSwitch", () => {
    it("returns the switch ID from target element", () => {
      const target = $("<button data-switch='switch-456'></button>");
      expect(Switch.parentSwitch(target)).to.equal("switch-456");
    });
  });

  describe("parentPromotionTarget", () => {
    it("returns the promotion target from target element", () => {
      const target = $("<button data-promotion-target='My Target'></button>");
      expect(Switch.parentPromotionTarget(target)).to.equal("My Target");
    });
  });

  describe("hasEmptyRequiredParameter", () => {
    it("returns true when required input is empty", () => {
      const form = $(`
        <form>
          <input type="text" required value="" />
        </form>
      `);

      expect(Switch.hasEmptyRequiredParameter(form)).to.be.true;
    });

    it("returns false when all required inputs are filled", () => {
      const form = $(`
        <form>
          <input type="text" required value="filled" />
        </form>
      `);

      expect(Switch.hasEmptyRequiredParameter(form)).to.be.false;
    });

    it("returns true when required select has no value", () => {
      // Create a select with no options - .val() will return null
      const form = $(`
        <form>
          <select required>
          </select>
        </form>
      `);

      expect(Switch.hasEmptyRequiredParameter(form)).to.be.true;
    });
  });

  describe("isProcessed", () => {
    it("returns true when trigger event is processed", () => {
      const triggerEvent = $("<div data-trigger-event-processed='true'></div>");
      expect(Switch.isProcessed(triggerEvent)).to.be.true;
    });

    it("returns false when trigger event is not processed", () => {
      const triggerEvent = $("<div data-trigger-event-processed='false'></div>");
      expect(Switch.isProcessed(triggerEvent)).to.be.false;
    });

    it("returns false when trigger event is null", () => {
      expect(Switch.isProcessed(null)).to.not.be.true;
    });
  });
});
