import { Utils } from "../../utils"
import ansiparse from "ansiparse";
var _ = require("lodash/");

export class LogLineTemplate {
  static render(logLine) {
    return `
    <div class="job-log-line">
      <span class="job-log-line-number">${logLine.number}</span><span class="job-log-line-body"><span>${this.renderOutput(logLine) || "&nbsp;"}</span></span>${this.renderTimestamp(logLine)}
    </div>
    `;
  }

  static renderOutput(logLine) {
    return ansiparse(logLine.output).map((parsed) => {
      return `<span class="${parsed.foreground}">${_.escape(parsed.text)}</span>`;
    }).join("");
  }

  static renderTimestamp(logLine) {
    return `
    <span class="job-log-line-timestamp" seconds="${logLine.timestampRelativeToCommandStartedAt()}">
      ${Utils.toHHMMSS(logLine.timestampRelativeToCommandStartedAt())}
    </span>
    `;
  }
}
