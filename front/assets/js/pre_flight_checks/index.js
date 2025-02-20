
import SecretsComponent from './secrets'
import AgentComponent from './agent'
import CommandsComponent from './commands'

export class PreFlightChecks {
  static init(prefixId) {
    if (this.arePreFlightChecksVisible(prefixId)) {
      return {
        commands: CommandsComponent.init(prefixId),
        secrets: SecretsComponent.init(prefixId),
        agent: AgentComponent.init(prefixId)
      }
    }
  }

  static arePreFlightChecksVisible(prefixId) {
    return !!(document.getElementById(`${prefixId}_submit`))
  }
}
