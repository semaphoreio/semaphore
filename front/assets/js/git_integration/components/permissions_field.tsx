import { Fragment } from "preact";

interface Props {
  permissions: string;
  checkboxPermissions?: boolean;
}

interface Permission {
  name: string;
  level: string;
}

export const PermissionsField = ({ permissions, checkboxPermissions = false }: Props) => {
  const permissionsList: Permission[] = permissions.split(`,`).map((p) => {
    const trimmed = p.trim();
    if (checkboxPermissions) {
      return { name: trimmed.replace(`:true`, ``), level: null };
    }
    const [name, level] = trimmed.split(`:`);
    return { name: name.trim(), level: level?.trim() };
  });

  return (
    <div className="mb3">
      <label className="f5 mv2">Required Permissions</label>
      <p className="f6 mv2">
        Please set the following permissions in your application settings:
      </p>
      <div className="f6 bg-washed-yellow mb3 ph3 pv2 ba b--black-075 br3">
        <ul className="list pl0 mb0">
          {permissionsList.map((permission, index) => (
            <li key={index} className="mv2 ml2" style={{ listStyleType: `disc` }}>
              <span className={checkboxPermissions ? `` : `b`}>{permission.name}</span>
              {!checkboxPermissions && permission.level && (
                <Fragment>
                  <span className="mh1">·</span>
                  <span className="o-70">{permission.level}</span>
                </Fragment>
              )}
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
};
