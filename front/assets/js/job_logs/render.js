import { Events } from "./events"
import { CommandStartedEvent } from "./events/command_started_event"
import { CommandOutputEvent } from "./events/command_output_event"
import { CommandFinishedEvent } from "./events/command_finished_event"
import { JobOutput } from "./job_output"
import { CommandTemplate } from "./templates/command"
import $ from "jquery"

export var Render = {
  init(options) {
    this.div = options.div
    this.metricTags = options.metricTags || [];
    this.isJobFinished = options.isJobFinished;
    this.jobOutput = new JobOutput();
  },

  start(options) {
    // Drop a loop left over from a previous job page before starting a new one.
    this.stop();

    this.stopped = false;
    this.init(options);
    this.tick();
  },

  //
  // Cancels the render loop. tick() reschedules itself at 0ms while events are
  // still arriving, so under Turbo this would otherwise keep spinning against
  // a detached container for as long as the tab stayed open.
  //
  stop() {
    this.stopped = true;

    clearTimeout(this.timeout);
    this.timeout = null;
  },

  tick() {
    if (this.stopped) { return }

    let events = Events.getAllItems();
    if(events.length > 0) {
      this.process(events)
    }

    if(Events.isRunning() || Events.notEmpty()) {
      this.timeout = setTimeout(this.tick.bind(this), 0);
    } else {
      this.afterFinish()
    }
  },

  process(events) {
    let t1 = performance.now();
    this.buildJobOutput(this.jobOutput, events);
    let t2 = performance.now();

    $(this.div).removeClass("job-log-loading");
    $(this.div).removeClass("job-log");
    $(this.div).addClass("job-log");

    let t3 = performance.now();
    this.render(this.jobOutput, this.isJobFinished);
    let t4 = performance.now();

    console.log(`Processing finished. total: ${(t4 - t1) / 1000} build: ${(t2 - t1) / 1000} render: ${(t4 - t3) / 1000}`);
  },

  buildJobOutput(jobOutput, events) {
    events.forEach((event) => {
      switch(this.typeOf(event)) {
        case "cmd_started": {
          jobOutput.createCommand(new CommandStartedEvent(event));
          break;
        }
        case "cmd_output": {
          jobOutput.append(new CommandOutputEvent(event));
          break;
        }
        case "cmd_finished": {
          jobOutput.finishLastCommand(new CommandFinishedEvent(event));
          break;
        }
        case "job_finished": {
          if (jobOutput.isEmpty()) {
            break;
          }

          if (jobOutput.lastCommand().isFinished() === false) {
            jobOutput.killLastCommand(new JobFinishedEvent(event));
          }
          break;
        }
        default: {
          break;
        }
      }
    });
  },

  render(jobOutput, isJobFinished) {
    let cmd = jobOutput.commandWithRenderingInProgress()

    if (cmd) {
      $(`[data-command-number=${cmd.id}]`).replaceWith(CommandTemplate.render(cmd, isJobFinished))
    }

    $(this.div).append(this.renderNewCommands(jobOutput, isJobFinished));

    jobOutput.markAllCommandsAsRendered();
  },

  renderNewCommands(jobOutput, isJobFinished) {
    return jobOutput.commandsWaitingToBeRendered().map((command) => {
      return CommandTemplate.render(command, isJobFinished)
    }).join("");
  },

  typeOf(event) {
    return event.event;
  },

  afterProcess() {
    if(this.callback !== null && this.callback !== undefined) {
      this.callback()
    }
  },

  onFinish(callback) {
    this.finishCallback = callback
  },

  afterFinish() {
    if(this.finishCallback !== null && this.finishCallback !== undefined) {
      this.finishCallback()
    }
  }
}
