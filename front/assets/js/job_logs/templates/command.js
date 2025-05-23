import { LogLineTemplate } from "./log_line"
import { Utils } from "../../utils"
var _ = require("lodash/");

export class CommandTemplate {
  static render(command, isJobFinished) {
    let cssClass = "";

    if (this.showLogLines(command, isJobFinished)) {
      cssClass += "open ";
    }

    if (command.hasEmptyOutput()) {
      cssClass += "empty ";
    }

    return `
    <div class="job-log-fold ${cssClass}" data-command-number="${command.id}">
      <div class="job-log-line command">
        <span class="job-log-line-number">${command.startingLineNumber}</span>
        <span class="job-log-line-body"><span>${_.escape(command.directive)}</span></span>
        <span class="job-log-line-time ${this.statusBackground(command, isJobFinished)}">
          ${this.renderSpinnerIfNotFullyFetched(command)}${this.status(command, isJobFinished)}${this.duration(command, isJobFinished)}
        </span>
        <span class="job-log-line-expand dn">
          ↓ Expand ↓
        </span>
      </div>

      <div cmd-lines-container ${this.logLinesVisibility(command, isJobFinished)}>
        ${this.renderLogLines(command.logLines)}
      </div>
    </div>
    `;
  }

  static logLinesVisibility(command, isJobFinished) {
    if (this.showLogLines(command, isJobFinished)) {
      return "";
    } else {
      return "class='dn'"
    }
  }

  static showLogLines(command, isJobFinished) {
    return (command.isFetching() && isJobFinished === false) || command.isFailed();
  }

  static renderSpinnerIfNotFullyFetched(command) {
    if (command.isFetching()) {
      return this.spinner();
    } else {
      return "";
    }
  }

  static spinner() {
    return "<span class='job-log-working'></span>&nbsp;";
  }

  static duration(command, isJobFinished) {
    if (command.isFinished()) {
      let durationInSeconds = command.finishedAt - command.startedAt;

      return `<span seconds='${durationInSeconds}'>${Utils.toHHMMSS(durationInSeconds)}</span>`;
    } else if (command.isFetching && isJobFinished === false) {
      let durationInSeconds = Math.floor(Date.now() / 1000) - command.startedAt;

      return `<span timer run seconds='${durationInSeconds}'>${Utils.toHHMMSS(durationInSeconds)}</span>`;
    } else {
      return "";
    }
  }

  static statusBackground(command, isJobFinished) {
    if (command.isPassed()) {
      return "bg-green";
    }

    if (command.isFailed()) {
      return "bg-red";
    }

    if (command.isFetching() && isJobFinished === false) {
      return "bg-indigo";
    }
  }

  static status(command, isJobFinished) {
    if (command.isPassed()) {
      return "Passed in&nbsp;"
    }

    if (command.isFailed()) {
      return "Failed in&nbsp;"
    }

    if (command.isFetching() && isJobFinished === true) {
      return "Fetching&nbsp;"
    }

    if (command.isFetching() && isJobFinished === false) {
      return "Running&nbsp;"
    }
  }

  static renderLogLines(logLines) {
    return logLines.map((logLine) => {
      return LogLineTemplate.render(logLine)
    }).join("");
  }
}
