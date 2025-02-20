import { Container } from '../../secrets/container.js'

export class ProjectSecrets {
    static init(injectedDataByBackend) {
        new Container({
            selector: 'org_secrets_items',
            editable: false,
            data: injectedDataByBackend.ProjectOrgSecrets,
            projectName: injectedDataByBackend.ProjectName,
            nextPageUrl: injectedDataByBackend.ProjectOrgSecretsNextPageUrl,
            canManageSecrets: window.InjectedDataByBackend.ProjectOrgSecrets.CanManage=="true",
            onlyButtonsOnSummary: false,
            useToggleButton: false
        })

        new Container({
            selector: 'project_secrets_items',
            editable: true,
            data: injectedDataByBackend.ProjectSecrets,
            projectName: injectedDataByBackend.ProjectName,
            nextPageUrl: "",
            canManageSecrets: window.InjectedDataByBackend.ProjectOrgSecrets.CanManage=="true",
            onlyButtonsOnSummary: false,
            useToggleButton: false
        })
    }
}