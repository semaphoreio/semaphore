import { Utils } from "../../utils"

export class CommandStartedEvent {
  constructor(options) {
    this.timestamp = options.timestamp;
    this.directive = options.directive;

    if (Utils.isBlank(this.timestamp)) throw "CommandStartedEvent can't have blank timestamp";
    if (Utils.isBlank(this.directive)) throw "CommandStartedEvent can't have blank directive";
  }
}
