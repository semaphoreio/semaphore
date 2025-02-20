import { Utils } from "../../utils"

export class CommandFinishedEvent {
  constructor(options) {
    this.timestamp = options.timestamp;
    this.directive = options.directive;
    this.exitCode = options.exit_code;
    this.startedAt = options.started_at;
    this.finishedAt = options.finished_at;

    if(Utils.isBlank(this.timestamp)) throw("CommandFinishedEvent can't have blank timestamp");
    if(Utils.isBlank(this.directive)) throw("CommandFinishedEvent can't have blank directive");
    if(Utils.isBlank(this.exitCode)) throw("CommandFinishedEvent can't have blank exitCode");
    if(Utils.isBlank(this.startedAt)) throw("CommandFinishedEvent can't have blank startedAt");
    if(Utils.isBlank(this.finishedAt)) throw("CommandFinishedEvent can't have blank finishedAt");
  }
}
