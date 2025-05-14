import { Pollman } from "../pollman"

export class PollmanList {
  constructor() {
  }

  clearAllOptions(container) {
    Pollman.stop();

    const attributes = Array.from(container.attributes);
    
    attributes.forEach(attribute => {
      if (attribute.name.startsWith("data-poll-param-")) {
        container.removeAttribute(attribute.name);
      }
    });
    
    Pollman.fetchAndReplace(container);

    Pollman.start();
  }

  updateOptionsAndFetch(container, options) {
    Pollman.stop();

    for(var key in options) {
      console.log("Updating param", key, options[key])
      container.setAttribute("data-poll-param-" + key, options[key]);
    }

    Pollman.fetchAndReplace(container);

    Pollman.start();
  }
}
