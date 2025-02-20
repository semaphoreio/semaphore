export class SecretsList {
    constructor(options) {
        this.secrets = options.secrets
        this.canManageSecrets = options.canManageSecrets
        this.selector = options.selector
        this.editable = options.editable
        this.projectName = options.projectName
        this.onlyButtonsOnSummary = options.onlyButtonsOnSummary
    }

    add(newSecrets) {
        this.secrets = this.secrets.concat(newSecrets)
        this.render()
    }

    render() {
        var area = this.selector;
        var secretsListHTML =
            this.secrets.map(function (secret) {
                return `<details class="bt b--black-075 pa3">
                <summary class="flex items-center justify-between pointer pl1 pr1">
                    <div class="mr2 center cf w-60 ">
                        ${lock_icon()}
                        <span>
                            <span class="ml2">${escapeHtml(secret.name)}</span>
                            ${this.render_summary_description(secret)}
                        </span>
                    </div>
                    <div class="items-center w-40 fr">
                    <div class="fr dib">
                    ${this.render_summary_timestamp(secret)}
                    ${this.render_buttons(secret)}
                    ${arrow_asset()}
                    </div>
                    </div>
                </summary>

                <div class="ml2 pl3 bl b--gray">
                ${this.render_expanded_timestamp(secret)}
                ${this.render_expanded_description(secret)}
                ${this.render_env_vars(secret.env_vars)}
                ${this.render_config_files(secret.files)}
                </div>
            </details>
`
            }.bind(this)).join('');

        area.innerHTML = secretsListHTML;
    }

    render_summary_timestamp(secret) {
        if (!this.onlyButtonsOnSummary) {
            return `<div class="f6 dib">Updated ${secret.updated_at} </div>`
        }

        return ''
    }

    render_summary_description(secret) {
        if (!this.onlyButtonsOnSummary) {
            return `<span class="f6 fw5 black-50 pl2">${escapeHtml(secret.description) || ""}</span>`
        }

        return ''
    }

    render_expanded_timestamp(secret) {
        if (!this.onlyButtonsOnSummary) {
            return ''
        }

        return `
            <div class="mt2 pt2">
                ${clock_icon()}
                <div class="f6 dib">Updated ${secret.updated_at} </div>
            </div>
        `
    }

    render_expanded_description(secret) {
        if (!this.onlyButtonsOnSummary || !secret.description) {
            return ''
        }

        return `
            <div class="mt2 pt2">
                <div class="f6 dib">${escapeHtml(secret.description)} </div>
            </div>
        `
    }

    render_env_vars(envVars) {
        if (envVars.lenght != 0) {
            return `<div class="mt2 pt2">
            <div class="">Environment Variables</div>
            <ul class="ml3 pl0 mt2">
                ${envVars.map(function (env_var) {
                    return `<li class="mt1">
                        <div class="code f6 green"> ${escapeHtml(env_var.name)} </div>
                        <span class="code f6 gray">md5 ${env_var.md5} </span>
                        </li>`;
                }).join('')}
                </ul></div>`;
        }

        return '';
    }

    render_config_files(configFiles) {
        if (configFiles.length != 0) {
            return `<div class="mt2">
            <div class="">Configuration Files</div>
            <ul class="ml3 pl0 mt2">${configFiles.map(function (config_file) {
                return `<li>
                    <div class="code f6 green">${escapeHtml(config_file.path)}</div>
                    <span class="code f6 gray">md5 ${config_file.md5} </span>
                    </li>`;
            }).join('')}
            </ul>
            </div>`;
        }

        return '';
    }

    render_buttons(secret) {
        if (this.editable && this.canManageSecrets) {
            var csrf_token = document.querySelector("meta[name='csrf-token']").content;
            return `<div class="dib"><div class="button-group ml3">
                <a href="${this.url_prefix()}/${secret.id}/edit" class="btn btn-secondary btn-small">Edit</a>
                <a href="${this.url_prefix()}/${secret.id}"
                    data-to="${this.url_prefix()}/${secret.id}"
                    data-method="delete" data-csrf="${csrf_token}" class="btn btn-secondary btn-small hover-red">Delete</a>
                 </div></div>`;
        } else {
            return '';
        }
    }

    url_prefix() {
        if (this.projectName == "") {
            return `/secrets`
        }

        return `/projects/${this.projectName}/settings/secrets`
    }
}

function lock_icon() {
    return `<svg height="16" width="16" xmlns="http://www.w3.org/2000/svg"><g fill="none" fill-rule="evenodd"><path d="M8 1a3 3 0 013 3v3H5V4a3 3 0 013-3z" stroke="#00a569" stroke-width="2"></path><path d="M13 6a1 1 0 011 1v8a1 1 0 01-1 1H3a1 1 0 01-1-1V7a1 1 0 011-1zM8 9a1 1 0 00-1 1v2a1 1 0 002 0v-2a1 1 0 00-1-1z" fill="#00a569"></path></g></svg>`
}

function clock_icon() {
    let assets_path = document.querySelector("meta[name='assets-path']").getAttribute("content");

    return `<img class="dib" src="${assets_path}/images/icn-clock-15.svg">`
}

function arrow_asset() {
    let assets_path = document.querySelector("meta[name='assets-path']").getAttribute("content");

    return `<img class="ml3 dib" src="${assets_path}/images/icn-more.svg">`
}
