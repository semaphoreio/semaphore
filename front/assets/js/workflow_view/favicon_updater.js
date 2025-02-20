/**
 * @prettier
 */

import { Favicon } from "../favicon";

export class FaviconUpdater {
  static init(args) {
    return new FaviconUpdater(args);
  }

  constructor({ interval = 4000, onStatusChange = () => {} } = {}) {
    this.setInterval(interval);
    this.onStatusChange = onStatusChange;
  }

  start() {
    this.stop();
    this.fetchStatus();
    this.fetchLoop = setInterval(() => {
      this.fetchStatus();
    }, this.interval);
  }

  stop() {
    clearInterval(this.fetchLoop);
    this.fetchLoop = undefined;
  }

  fetchStatus() {
    return this.fetch()
      .then((response) => {
        return response.text();
      })
      .then((text) => {
        this.setStatus(text);
      });
  }

  fetch() {
    return fetch(this.statusUrl);
  }

  setPipelineStatusUrl(url) {
    this.statusUrl = url;
    this.start();
  }

  setStatus(state) {
    if (this.currentState !== state) {
      this.onStatusChange(state);
      this.currentState = state;
    }

    Favicon.replace(state);
    if (state === "passed") {
      this.stop();
    }
  }

  setInterval(miliseconds) {
    this.interval = miliseconds;
  }
}
