import { Utils } from "../../utils"
import anser from "anser";
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
    const chunks = anser.ansiToJson(logLine.output);
    const hasContent = chunks.some((parsed) => parsed.content);
    if (!hasContent) {
      return "";
    }
    return chunks.map((parsed) => {
      const styles = this.buildStyles(parsed);
      const styleAttr = styles.length > 0 ? ` style="${styles.join("; ")}"` : "";
      return `<span${styleAttr}>${_.escape(parsed.content)}</span>`;
    }).join("");
  }

  static buildStyles(parsed) {
    const styles = [];

    if (parsed.fg) {
      styles.push(`color: rgb(${parsed.fg})`);
    }

    if (parsed.bg) {
      styles.push(`background-color: rgb(${parsed.bg})`);
    }

    if (parsed.decorations && parsed.decorations.length > 0) {
      if (parsed.decorations.includes("bold")) {
        styles.push("font-weight: bold");
      }
      if (parsed.decorations.includes("italic")) {
        styles.push("font-style: italic");
      }
      const textDecorations = [];
      if (parsed.decorations.includes("underline")) {
        textDecorations.push("underline");
      }
      if (parsed.decorations.includes("strikethrough")) {
        textDecorations.push("line-through");
      }
      if (textDecorations.length > 0) {
        styles.push(`text-decoration: ${textDecorations.join(" ")}`);
      }
    }

    return styles;
  }

  static renderTimestamp(logLine) {
    return `
    <span class="job-log-line-timestamp" seconds="${logLine.timestampRelativeToCommandStartedAt()}">
      ${Utils.toHHMMSS(logLine.timestampRelativeToCommandStartedAt())}
    </span>
    `;
  }
}
