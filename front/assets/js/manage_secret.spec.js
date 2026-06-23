/**
 * @prettier
 */

import { expect } from "chai";
import { ManageSecret } from "./manage_secret";

describe("ManageSecret", () => {
  describe("envVarElement", () => {
    it("disables browser autocomplete on the value input so secret values are not cached", () => {
      let [element, , , , envVarValueId] = ManageSecret.envVarElement(
        { name: "", value: "", md5: "" },
        0
      );

      document.body.innerHTML = element;
      let valueInput = document.getElementById(envVarValueId);

      expect(valueInput).to.not.be.null;
      expect(valueInput.getAttribute("autocomplete")).to.eq("off");
      // Keep password managers from offering to store/fill the value.
      expect(valueInput.hasAttribute("data-1p-ignore")).to.be.true;
      expect(valueInput.getAttribute("data-lpignore")).to.eq("true");
    });
  });
});
