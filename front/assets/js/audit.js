export class AuditLogs {
    static init() {
        if (this.areAuditLogExportSettingsVisible()) {
            return new AuditLogs
        }
    }

    constructor() {
        this.hostOptions = document.querySelectorAll('input[name="s3[host]"]');
        this.zone = document.getElementById('region-options');
        this.registerShowZoneHandler();
        this.handleChangeOption();

        this.handleInstanceRoleChange();
        this.toggleInstanceRole();
    }

    registerShowZoneHandler() {
        this.hostOptions.forEach(element => {
            element.addEventListener('click', (e) => {
                this.handleChangeOption()
            })
        });
    }

    handleChangeOption() {
        if (document.getElementById('awss3').checked) {
            this.zone.style.display = 'block';
        } else {
            this.zone.style.display = 'none';
        }
    }

    toggleInstanceRole() {
        const instanceRoleCheckBox = document.getElementById('s3_instance_role');
        if (instanceRoleCheckBox) {
            if (instanceRoleCheckBox.checked) {
                document.getElementById('audit-user-credentials').classList.add('dn');
                document.getElementById('audit-instance-role-warning').classList.remove('dn');
            } else {
                document.getElementById('audit-user-credentials').classList.remove('dn');
                document.getElementById('audit-instance-role-warning').classList.add('dn');
            }
        }
    }

    handleInstanceRoleChange() {
        const instanceRoleCheckBox = document.getElementById('s3_instance_role');
        if (instanceRoleCheckBox) {
            instanceRoleCheckBox.addEventListener('change', (e) => {
                this.toggleInstanceRole();
            });
        }
    }

    static areAuditLogExportSettingsVisible() {
        return !!(document.getElementById(`audit_stream_config_submit`));
    }
}
