import { Pollman } from "../pollman"

export class PollmanList {
  constructor() {
  }

  clearAllOptions(container) {
    const attributes = Array.from(container.attributes);
    
    attributes.forEach(attribute => {
      if (attribute.name.startsWith("data-poll-param-")) {
        container.removeAttribute(attribute.name);
      }
    });
  }

  updateOptionsAndFetch(container, options) {
    Pollman.stop();

    for(var key in options) {
      container.setAttribute("data-poll-param-" + key, options[key]);
    }

    Pollman.fetchAndReplace(container);

    Pollman.start();
  }
}
