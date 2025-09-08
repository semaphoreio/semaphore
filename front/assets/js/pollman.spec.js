/**
 * @prettier
 */
import { expect } from "chai";
import { Pollman } from "./pollman";
import sinon from "sinon";

describe("Pollman", () => {
  describe("#requestUrl", () => {
    beforeEach(() => {
      // Mock window.location.origin for the host validation
      global.window = {
        location: {
          origin: "https://example.com"
        }
      };
      global.URL = class URL {
        constructor(url, base) {
          if (url.startsWith('/')) {
            this.href = base + url;
            this.origin = base;
          } else {
            this.href = url;
            // Extract origin from full URL
            const match = url.match(/^(https?:\/\/[^\/]+)/);
            this.origin = match ? match[1] : base;
          }
        }
      };
    });

    it("returns the URL from where to fetch the updated HTML node", () => {
      let node_mock = {
        attributes: [
          { name: "data-poll-href", value: "/resources/get" },
          { name: "data-poll-param-page", value: "1" },
          { name: "data-poll-param-color", value: "green" },
          { name: "data-poll-param-state", value: "passed" },
        ],
        getAttribute: function (name) {
          let attribute = this.attributes.find(
            (attribute) => attribute.name === name
          );
          return attribute.value;
        },
      };
      expect(Pollman.requestUrl(node_mock)).to.equal(
        "https://example.com/resources/get?page=1&color=green&state=passed"
      );
    });

    it("throws error for external domain", () => {
      let node_mock = {
        attributes: [
          { name: "data-poll-href", value: "https://malicious.com/script.js" },
        ],
        getAttribute: function (name) {
          let attribute = this.attributes.find(
            (attribute) => attribute.name === name
          );
          return attribute.value;
        },
      };
      expect(() => Pollman.requestUrl(node_mock)).to.throw(
        "Invalid or unauthorized data-poll-href URL"
      );
    });

    it("allows same origin with full URL", () => {
      let node_mock = {
        attributes: [
          { name: "data-poll-href", value: "https://example.com/api/poll" },
          { name: "data-poll-param-id", value: "123" },
        ],
        getAttribute: function (name) {
          let attribute = this.attributes.find(
            (attribute) => attribute.name === name
          );
          return attribute.value;
        },
      };
      expect(Pollman.requestUrl(node_mock)).to.equal(
        "https://example.com/api/poll?id=123"
      );
    });
  });

  describe("#elementsToRefresh", () => {
    before(function () {
      Pollman.init({startLooper: false});
      document.body.innerHTML = `
        <div data-poll-background="" data-poll-href="/resources/1" data-poll-state="poll"></div>
        <div data-poll-href="/resources/2" data-poll-state="poll"></div>
      `;
    });
    afterEach(function () {
      if (Pollman.pageIsVisible && Pollman.pageIsVisible.restore)
        Pollman.pageIsVisible.restore();
    });
    it("returns correct elements for visible page", () => {
      sinon.stub(Pollman, "pageIsVisible").returns(true);
      let elements = Pollman.elementsToRefresh();
      expect(elements.length).to.equal(2);
      expect(elements[0].outerHTML).to.equal(
        `<div data-poll-background="" data-poll-href="/resources/1" data-poll-state="poll"></div>`
      );
      expect(elements[1].outerHTML).to.equal(
        `<div data-poll-href="/resources/2" data-poll-state="poll"></div>`
      );
    });
    it("returns correct elements for visible page when forced to", () => {
      sinon.stub(Pollman, "pageIsVisible").returns(true);
      let elements = Pollman.elementsToRefresh({ forceRefresh: true });
      expect(elements.length).to.equal(2);
      expect(elements[0].outerHTML).to.equal(
        `<div data-poll-background="" data-poll-href="/resources/1" data-poll-state="poll"></div>`
      );
      expect(elements[1].outerHTML).to.equal(
        `<div data-poll-href="/resources/2" data-poll-state="poll"></div>`
      );
    });
    it("returns correct elements for not active tab", () => {
      sinon.stub(Pollman, "pageIsVisible").returns(false);
      let elements = Pollman.elementsToRefresh();
      expect(elements.length).to.equal(1);
      expect(elements[0].outerHTML).to.equal(
        `<div data-poll-background="" data-poll-href="/resources/1" data-poll-state="poll"></div>`
      );
    });
    it("returns correct elements for not active tab when forced to ", () => {
      sinon.stub(Pollman, "pageIsVisible").returns(false);
      let elements = Pollman.elementsToRefresh({ forceRefresh: true });
      expect(elements.length).to.equal(2);
      expect(elements[0].outerHTML).to.equal(
        `<div data-poll-background="" data-poll-href="/resources/1" data-poll-state="poll"></div>`
      );
      expect(elements[1].outerHTML).to.equal(
        `<div data-poll-href="/resources/2" data-poll-state="poll"></div>`
      );
    });
  });
});
