import { Pollman } from "../pollman"

export class PollmanList {
  constructor() {
  }

  updateOptionsAndFetch(container, options) {
    console.log("UPDATE")
    console.log(options)
    Pollman.stop();

    for(var key in options) {
      console.log("SET")
      console.log("data-poll-param-" + key)
      console.log(options[key])
      container.setAttribute("data-poll-param-" + key, options[key]);
    }

    Pollman.fetchAndReplace(container);

    Pollman.start();
  }
}
