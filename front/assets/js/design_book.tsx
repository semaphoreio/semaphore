import { render } from "preact";

import { App } from "./design_book/App";

const root = document.getElementById(`design-book-root`);

if (root) {
  render(<App/>, root);
}
