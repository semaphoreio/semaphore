import { CommandTemplate } from "./command"

export class JobOutputTemplate {
  static render(jobOutput, isJobFinished) {
    return jobOutput.commands.map((command) => {
      return CommandTemplate.render(command, isJobFinished);
    }).join("");
  }
}
