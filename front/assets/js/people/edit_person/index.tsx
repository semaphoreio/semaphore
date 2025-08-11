import { Fragment, render, createContext } from "preact";
import { useContext, useState } from "preact/hooks";

import * as toolbox from "js/toolbox";
import { ChangeEvent } from "react-dom/src";

export default function ({
  dom,
  config: jsonConfig,
}: {
  dom: Element;
  config: any;
}) {
  const buttonContainer = document.createElement(`div`);

  render(
    <Config.Provider value={State.fromJSON(jsonConfig as DOMStringMap)}>
      <Button/>
    </Config.Provider>,
    buttonContainer
  );

  dom.replaceWith(...buttonContainer.childNodes);
}

interface Response {
  message: string;
  status: `none` | `loading` | `error` | `success`;
}

export const Button = () => {
  const { user } = useContext(Config);
  const [isOpen, setIsOpen] = useState(false);
  const [changed, setChanged] = useState(false);

  const [defaultRole, setDefaultRole] = useState<UserRole>(
    user.roles.find((role) => role.isSelected)
  );
  const [selectedRole, setSelectedRole] = useState<UserRole>(defaultRole);
  const [roleResponse, setRoleResponse] = useState<Response>({
    message: ``,
    status: `none`,
  });

  const [defaultEmail, setDefaultEmail] = useState(user.email);
  const [email, setEmail] = useState(defaultEmail);
  const [emailResponse, setEmailResponse] = useState<Response>({
    message: ``,
    status: `none`,
  });

  const roleChanged = defaultRole != selectedRole;
  const emailChanged = defaultEmail != email;

  const ResponseHandler = (props: { response: Response, }) => {
    return (
      <div
        className={`f6 tr mt2 ${
          props.response.status == `error` ? `red` : `green`
        }`}
      >
        {props.response.status == `loading` && (
          <toolbox.Asset path="images/spinner.svg"/>
        )}
        {props.response.status != `loading` && props.response.message}
      </div>
    );
  };

  const close = () => {
    if (changed) {
      window.location.reload();
    } else {
      setIsOpen(false);
    }
  };

  const open = () => {
    setIsOpen(true);
  };

  const saveRole = (selectedRole: UserRole) => {
    setRoleResponse({
      message: ``,
      status: `loading`,
    });

    return user.assignRoleUrl
      .call({
        body: { user_id: user.id, role_id: selectedRole.id, member_type: user.memberType },
      })
      .then((resp) => {
        if (resp.error) {
          setRoleResponse({
            message: resp.error,
            status: `error`,
          });
          return;
        }
        setRoleResponse({
          message: resp.data.message,
          status: `success`,
        });
        setDefaultRole(selectedRole);

        setChanged(true);
      })
      .catch((error) => {
        setRoleResponse({
          message: error.error,
          status: `error`,
        });
      });
  };

  const saveEmail = (email: string) => {
    setEmailResponse({
      message: ``,
      status: `loading`,
    });
    return user.changeEmailUrl
      .call({
        body: { user_id: user.id, email: email },
      })
      .then((resp) => {
        if (resp.error) {
          setEmailResponse({
            message: resp.error,
            status: `error`,
          });
          return;
        }
        setEmailResponse({
          message: resp.data.message,
          status: `success`,
        });
        setDefaultEmail(email);

        setChanged(true);
      });
  };

  const save = () => {
    if (roleChanged) {
      void saveRole(selectedRole);
    }

    if (emailChanged) {
      void saveEmail(email);
    }
  };

  const onEmailChanged = (e: ChangeEvent<HTMLInputElement>) => {
    setEmail(e.currentTarget.value);
  };

  return (
    <Fragment>
      <button
        className="pointer flex items-center js-dropdown-menu-trigger btn-secondary btn"
        onClick={open}
      >
        <span className="material-symbols-outlined mr1">manage_accounts</span>
        <span>Edit</span>
      </button>
      <toolbox.Modal isOpen={isOpen} close={close} title="Edit user">
        <div className="pa3">
          <div className="mb3">
            <label className="db mb2 b">Email address</label>
            <div className="flex">
              <input
                type="email"
                className="form-control w-100"
                value={email}
                onChange={onEmailChanged}
                disabled={emailResponse.status == `loading`}
              />
            </div>
            <ResponseHandler response={emailResponse}/>
          </div>

          <div className="mb3">
            <label className="db mb2 b">Password</label>
            <PasswordReset user={user}/>
          </div>

          <div>
            <label className="db mb2 b">Role</label>
            <ChangeRole
              user={user}
              selectRole={setSelectedRole}
              selectedRole={selectedRole}
            />
            <ResponseHandler response={roleResponse}/>
          </div>
          <div className="flex justify-end mt4">
            <button className="btn btn-secondary mr3" onClick={close}>
                Cancel
            </button>

            <button
              className="btn btn-primary"
              onClick={save}
              disabled={!roleChanged && !emailChanged}
            >
                Save changes
            </button>
          </div>
        </div>
      </toolbox.Modal>
    </Fragment>
  );
};

const ChangeRole = (props: {
  user: User;
  selectRole: (role: UserRole) => void;
  selectedRole?: UserRole;
}) => {
  const user = props.user;

  return (
    <div className="flex flex-column br3 shadow-1 overflow-hidden ba b--black-10">
      {user.roles.map((role) => {
        const selected = props.selectedRole?.id == role.id;
        let classes = `bg-white hover-bg-washed-gray pointer pv2 ph3 bb b--black-075`;
        if (selected) {
          classes = `pointer pv2 ph3 bb b--black-075 bg-dark-gray white`;
        }

        return (
          <div
            key={role.id}
            className={classes}
            onClick={() => props.selectRole(role)}
          >
            <label className="pointer">
              <p className="b f5 mb0">{role.name}</p>
              <p
                className={`f6 mb0 measure ${selected ? `light-gray` : `gray`}`}
              >
                {role.description}
              </p>
            </label>
          </div>
        );
      })}
    </div>
  );
};

enum PasswordResetState {
  Start,
  ConfirmReset,
  NewPassword,
}

interface PasswordResetProps {
  user: User;
}
const PasswordReset = (props: PasswordResetProps) => {
  const [loading, setLoading] = useState(false);
  const [tempPassword, setTempPassword] = useState(``);
  const [state, setState] = useState<PasswordResetState>(
    PasswordResetState.Start
  );

  const [copied, setCopied] = useState(false);

  const copyPassword = () => {
    void navigator.clipboard.writeText(tempPassword).then(() => {
      setCopied(true);
    });
  };

  const resetPassword = () => {
    setLoading(true);
    void props.user.resetPasswordUrl
      .call()
      .then((res) => {
        setTempPassword(res.data.password);
        setState(PasswordResetState.NewPassword);
      })
      .finally(() => {
        setLoading(false);
      });
  };

  switch (state) {
    case PasswordResetState.ConfirmReset:
      return (
        <div className="bg-washed-yellow pa3 br2">
          <p className="mt0 mb3">
            Are you sure you want to reset the password? A new temporary
            password will be generated.
          </p>
          <div className="flex justify-end">
            {loading && <toolbox.Asset path="images/spinner.svg"/>}
            {!loading && (
              <Fragment>
                <button
                  disabled={loading}
                  className="btn btn-secondary mr3"
                  onClick={() => setState(PasswordResetState.Start)}
                >
                  Cancel
                </button>
                <button
                  disabled={loading}
                  className="btn btn-primary"
                  onClick={resetPassword}
                >
                  Reset password
                </button>
              </Fragment>
            )}
          </div>
        </div>
      );
    case PasswordResetState.NewPassword:
      return (
        <div className="bg-washed-yellow pa3 br2">
          <div className="flex items-center justify-between">
            <span className="gray">New temporary password:</span>
            <div className="flex items-center justify-between">
              <code className="f6">{tempPassword}</code>

              <toolbox.Tooltip
                content={
                  <span className="f6">
                    {copied ? `Copied!` : `Copy password`}
                  </span>
                }
                anchor={
                  <toolbox.MaterializeIcon
                    onClick={copyPassword}
                    name={copied ? `done` : `content_copy`}
                    className="pointer"
                  />
                }
              />
            </div>
          </div>
        </div>
      );
    default:
    case PasswordResetState.Start:
      return (
        <button
          className="btn btn-secondary"
          onClick={() => setState(PasswordResetState.ConfirmReset)}
          disabled={loading}
        >
          Reset password
        </button>
      );
  }
};

export class State {
  user: User;
  accessProvider: toolbox.AccessProvider;
  featureProvider: toolbox.FeatureProvider;

  static fromJSON(rawJson: DOMStringMap): State {
    const config = this.default();
    const json = JSON.parse(rawJson.config);

    config.user = User.fromJSON(json.user);
    config.featureProvider = toolbox.FeatureProvider.fromJSON(
      json.meta.features
    );
    config.accessProvider = toolbox.AccessProvider.fromJSON(
      json.meta.permissions
    );

    return config;
  }

  static default(): State {
    const config = new State();
    config.accessProvider = new toolbox.AccessProvider();
    config.featureProvider = new toolbox.FeatureProvider();
    return config;
  }
}

class UserRole {
  id: string;
  isSelected: boolean;
  description: string;
  name: string;

  constructor({
    id,
    isSelected,
    description,
    name,
  }: {
    id: string;
    isSelected: boolean;
    description: string;
    name: string;
  }) {
    this.id = id;
    this.isSelected = isSelected;
    this.description = description;
    this.name = name;
  }
}

class User {
  id: string;
  name: string;
  email: string;
  memberType: string;

  roles: UserRole[] = [];
  changeEmailUrl: toolbox.APIRequest.Url<{ email: string, message: string, }>;
  assignRoleUrl: toolbox.APIRequest.Url<{ password: string, message: string, }>;
  resetPasswordUrl: toolbox.APIRequest.Url<{
    password: string;
    message: string;
  }>;

  static fromJSON(json: any): User {
    const user = new User();
    user.id = json.id as string;
    user.name = json.name as string;
    user.email = json.email as string;
    user.memberType = json.member_type as string;
    user.roles = json.roles.map((role: any) => {
      return new UserRole({
        id: role.id,
        name: role.role_name,
        description: role.role_description,
        isSelected: role.is_selected,
      });
    });

    user.assignRoleUrl = toolbox.APIRequest.Url.fromJSON(json.assign_role_url);
    user.changeEmailUrl = toolbox.APIRequest.Url.fromJSON(
      json.change_email_url
    );
    user.resetPasswordUrl = toolbox.APIRequest.Url.fromJSON(
      json.reset_password_url
    );

    return user;
  }
}

export const Config = createContext<State>(State.default());
