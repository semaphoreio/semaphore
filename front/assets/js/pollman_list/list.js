import { Pollman } from "../pollman"

export class PollmanList {
  constructor() {
  }

  updateOptionsAndFetch(container, options) {
    Pollman.stop();

    for(var key in options) {
      console.log("Setting poll parameter", key, options[key]);
      container.setAttribute("data-poll-param-" + key, options[key]);
    }

    Pollman.fetchAndReplace(container);

    Pollman.start();
  }
}
