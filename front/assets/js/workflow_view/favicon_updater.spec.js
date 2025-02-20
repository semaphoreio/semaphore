/**
 * @prettier
 */

import { expect } from "chai";
import { FaviconUpdater } from "./favicon_updater";
import sinon from "sinon";

function stubbedUpdater({ state: resolvedState } = { state: "passed" }) {
  let updater = FaviconUpdater.init({
    interval: 1000,
    onStatusChange: (state) => {
      document.querySelectorAll("#foo")[0].innerText = state;
    },
  });

  sinon.stub(updater, "fetch").callsFake(() => {
    return new Promise((resolve) => {
      resolve({
        text: () => resolvedState,
      });
    });
  });

  updater.setPipelineStatusUrl("https://some_host/status");

  return updater;
}

describe("FaviconUpdater", () => {
  beforeEach(() => {
    document.body.innerHTML = `<div id="foo"></div>`;
  });

  it("Handles passed status change correctly", () => {
    let updater = stubbedUpdater();
    return updater
      .fetchStatus()
      .then(() => {
        expect(document.querySelectorAll("#foo")[0].innerText).to.eq("passed");
        expect(updater.fetchLoop).to.be.undefined;
      })
      .finally(() => {
        updater.stop();
      });
  });

  it("Handles running status change correctly", () => {
    let state = "running";
    let updater = stubbedUpdater({ state });
    return updater
      .fetchStatus()
      .then(() => {
        expect(document.querySelectorAll("#foo")[0].innerText).to.eq(state);
        expect(updater.fetchLoop).to.not.be.undefined;
      })
      .finally(() => {
        updater.stop();
      });
  });

  it("Handles failed status change correctly", () => {
    let state = "failed";
    let updater = stubbedUpdater({ state });
    return updater
      .fetchStatus()
      .then(() => {
        expect(document.querySelectorAll("#foo")[0].innerText).to.eq(state);
        expect(updater.fetchLoop).to.not.be.undefined;
      })
      .finally(() => {
        updater.stop();
      });
  });

  it("Handles stopping status change correctly", () => {
    let state = "stopping";
    let updater = stubbedUpdater({ state });
    return updater
      .fetchStatus()
      .then(() => {
        expect(document.querySelectorAll("#foo")[0].innerText).to.eq(state);
        expect(updater.fetchLoop).to.not.be.undefined;
      })
      .finally(() => {
        updater.stop();
      });
  });

  it("Handles stopped status change correctly", () => {
    let state = "stopped";
    let updater = stubbedUpdater({ state });
    return updater
      .fetchStatus()
      .then(() => {
        expect(document.querySelectorAll("#foo")[0].innerText).to.eq(state);
        expect(updater.fetchLoop).to.not.be.undefined;
      })
      .finally(() => {
        updater.stop();
      });
  });

  it("Handles canceled status change correctly", () => {
    let state = "canceled";
    let updater = stubbedUpdater({ state });
    return updater
      .fetchStatus()
      .then(() => {
        expect(document.querySelectorAll("#foo")[0].innerText).to.eq(state);
        expect(updater.fetchLoop).to.not.be.undefined;
      })
      .finally(() => {
        updater.stop();
      });
  });

  it("Handles pending status change correctly", () => {
    let state = "pending";
    let updater = stubbedUpdater({ state });
    return updater
      .fetchStatus()
      .then(() => {
        expect(document.querySelectorAll("#foo")[0].innerText).to.eq(state);
        expect(updater.fetchLoop).to.not.be.undefined;
      })
      .finally(() => {
        updater.stop();
      });
  });
});
