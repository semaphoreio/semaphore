import _ from "lodash"
import yaml from "js-yaml"

import { expect } from "chai"
import { CommitDialogTemplate } from "./dialog"

describe("CommitDialogTemplate", () => {

  describe("#renderDiffLines", () => {
    let oldYAML = `version: "1.0"
name: Pipeline 1

blocks:
  - name: A
    task:
      jobs:
        - name: A
          commands: B
`

    describe("when there are no changes", () => {
      let newYAML = _.cloneDeep(oldYAML)

      it("has no line additions", () => {
        let diffLines = CommitDialogTemplate.renderDiffLines(oldYAML, newYAML)

        expect(diffLines.addedLinesCount).to.equal(0)
      })

      it("has no line removals", () => {
        let diffLines = CommitDialogTemplate.renderDiffLines(oldYAML, newYAML)

        expect(diffLines.addedLinesCount).to.equal(0)
      })

      it("has expected lines", () => {
        let diffLines = CommitDialogTemplate.renderDiffLines(oldYAML, newYAML)

        expect(diffLines.lines).to.equal([
          "<tr>",
          "  <td>1</td>",
          "  <td>1</td>",
          "  <td>version: &quot;1.0&quot;</td>",
          "</tr>",
          "<tr>",
          "  <td>2</td>",
          "  <td>2</td>",
          "  <td>name: Pipeline 1</td>",
          "</tr>",
          "<tr>",
          "  <td>3</td>",
          "  <td>3</td>",
          "  <td></td>",
          "</tr>",
          "<tr>",
          "  <td>4</td>",
          "  <td>4</td>",
          "  <td>blocks:</td>",
          "</tr>",
          "<tr>",
          "  <td>5</td>",
          "  <td>5</td>",
          "  <td>  - name: A</td>",
          "</tr>",
          "<tr>",
          "  <td>6</td>",
          "  <td>6</td>",
          "  <td>    task:</td>",
          "</tr>",
          "<tr>",
          "  <td>7</td>",
          "  <td>7</td>",
          "  <td>      jobs:</td>",
          "</tr>",
          "<tr>",
          "  <td>8</td>",
          "  <td>8</td>",
          "  <td>        - name: A</td>",
          "</tr>",
          "<tr>",
          "  <td>9</td>",
          "  <td>9</td>",
          "  <td>          commands: B</td>",
          "</tr>"
        ].join("\n"))
      })
    })

    describe("has line changes produced by json parse/dump", () => {
      let newYAML = yaml.safeDump(yaml.safeLoad(oldYAML))

      it("has line additions", () => {
        let diffLines = CommitDialogTemplate.renderDiffLines(oldYAML, newYAML)

        expect(diffLines.addedLinesCount).to.equal(1)
      })

      it("has line removals", () => {
        let diffLines = CommitDialogTemplate.renderDiffLines(oldYAML, newYAML)

        expect(diffLines.addedLinesCount).to.equal(1)
      })

      it("has line changes", () => {
        let diffLines = CommitDialogTemplate.renderDiffLines(oldYAML, newYAML)

        expect(diffLines.lines).to.equal([
          "<tr class=line-removed>",
          "  <td>1</td>",
          "  <td></td>",
          "  <td>version: &quot;1.0&quot;</td>",
          "</tr>",
          "<tr class=line-added>",
          "  <td></td>",
          "  <td>1</td>",
          "  <td>version: &#39;1.0&#39;</td>",
          "</tr>",
          "<tr>",
          "  <td>2</td>",
          "  <td>2</td>",
          "  <td>name: Pipeline 1</td>",
          "</tr>",
          "<tr class=line-removed>",
          "  <td>3</td>",
          "  <td></td>",
          "  <td></td>",
          "</tr>",
          "<tr>",
          "  <td>4</td>",
          "  <td>3</td>",
          "  <td>blocks:</td>",
          "</tr>",
          "<tr>",
          "  <td>5</td>",
          "  <td>4</td>",
          "  <td>  - name: A</td>",
          "</tr>",
          "<tr>",
          "  <td>6</td>",
          "  <td>5</td>",
          "  <td>    task:</td>",
          "</tr>",
          "<tr>",
          "  <td>7</td>",
          "  <td>6</td>",
          "  <td>      jobs:</td>",
          "</tr>",
          "<tr>",
          "  <td>8</td>",
          "  <td>7</td>",
          "  <td>        - name: A</td>",
          "</tr>",
          "<tr>",
          "  <td>9</td>",
          "  <td>8</td>",
          "  <td>          commands: B</td>",
          "</tr>"
        ].join("\n"))
      })
    })
  })

})
