import { Container } from '../secrets/container'

export class OrganizationSecrets {
  static init(injectedDataByBackend) {
    if (injectedDataByBackend.Secrets.length > 0) {
      new Container({
        selector: 'secrets_items',
        editable: true,
        data: injectedDataByBackend.Secrets,
        nextPageUrl: injectedDataByBackend.NextPageUrl,
        canManageSecrets: injectedDataByBackend.CanManageSecrets=="true",
        projectName: "",
        onlyButtonsOnSummary: true,
        useToggleButton: true
      })
    }
  }
}