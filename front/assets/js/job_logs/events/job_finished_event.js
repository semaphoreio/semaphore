import { Utils } from "../../utils"

export class JobFinishedEvent {
  constructor(options) {
    this.timestamp = options.timestamp;
    this.result = options.result;

    if(Utils.isBlank(this.timestamp)) throw("JobFinishedEvent can't have blank timestamp");
    if(Utils.isBlank(this.result)) throw("JobFinishedEvent can't have blank result");
  }
}
