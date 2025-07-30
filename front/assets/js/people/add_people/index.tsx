import { Fragment, render, VNode } from "preact";
import { Modal } from "js/toolbox";
import { useContext, useEffect, useReducer, useState } from "preact/hooks";
import * as toolbox from "js/toolbox";
import _ from "lodash";
import { ChangeEvent } from "react-dom/src";
import styled from "styled-components";
import { Config, AppConfig, RawConfig } from "./config";
import { AddPeopleState, AvailableProviderTypes, Collaborator, PeopleStateReducer, Person, PersonState, UserProvider } from "./types";

export default function ({
  dom,
  config: jsonConfig,
}: {
  dom: HTMLElement;
  config: RawConfig;
}) {
  render(
    <Config.Provider value={AppConfig.fromJSON(jsonConfig)}>
      <App/>
    </Config.Provider>,
    dom
  );
}

export const App = () => {
  const [isOpen, setIsOpen] = useState(false);

  const close = (reload: boolean) => {
    if (reload) {
      window.location.reload();
    } else {
      setIsOpen(false);
    }
  };

  const open = () => {
    setIsOpen(true);
  };

  return (
    <Fragment>
      <button className="btn btn-primary flex items-center" onClick={open}>
        <span className="material-symbols-outlined mr2">person_add</span>
        {`Add people`}
      </button>
      <Modal isOpen={isOpen} close={() => close(false)} title="Add new people" width="w-70-m">
        <AddNewUsers close={close}/>
      </Modal>
    </Fragment>
  );
};

const AddNewUsers = (props: { close: (reload: boolean) => void, }) => {
  const config = useContext(Config);

  const userProviders = AvailableProviderTypes.filter((type) =>
    config.allowedProviders.includes(type)
  );

  const [currentProvider, setCurrentProvider] = useState<UserProvider>(
    userProviders[0]
  );
  const [collaborators, setCollaborators] = useState<Collaborator[]>([]);

  const [loading, setLoading] = useState(true);


  useEffect(() => {
    void config.collaboratorListUrl
      .call()
      .then((resp) => {
        const collaborators = (resp.data.collaborators as any[]).map(
          Collaborator.fromJSON
        );

        setCollaborators(collaborators);
      })
      .finally(() => {
        setLoading(false);
      });
  }, []);

  const userProviderBox = (provider: UserProvider) => {
    const Link = (props: { icon: VNode, title: string, }) => {
      return (
        <ActiveShadowLink
          className={`flex-grow-1 btn btn-secondary ${
            currentProvider === provider ? `active` : ``
          }`}
          disabled={loading}
          onClick={() => setCurrentProvider(provider)}
        >
          <div className="inline-flex items-center">
            {props.icon}
            <span>{props.title}</span>
          </div>
        </ActiveShadowLink>
      );
    };

    switch (provider) {
      case UserProvider.Email:
        return (
          <Link
            title="Email"
            icon={
              <span className="material-symbols-outlined mr2 f4 b">mail</span>
            }
          />
        );
      case UserProvider.GitHub:
        return (
          <Link
            title="GitHub"
            icon={<toolbox.Asset path="images/icn-github.svg"/>}
          />
        );
      case UserProvider.Bitbucket:
        return (
          <Link
            title="Bitbucket"
            icon={<toolbox.Asset path="images/icn-bitbucket.svg"/>}
          />
        );
      case UserProvider.GitLab:
        return (
          <Link
            title="GitLab"
            icon={<toolbox.Asset path="images/icn-gitlab.svg"/>}
          />
        );
    }
  };

  return (
    <div className="pa4">
      {userProviders.length > 1 && (
        <div className="mb3 button-group w-100 items-center">
          {userProviders.map(userProviderBox)}
        </div>
      )}

      {userProviders.map((provider, idx) => {
        if (currentProvider !== provider.toLowerCase()) {
          return;
        }
        if (currentProvider === UserProvider.Email) {
          return <ProvideViaEmail key={idx} onCancel={props.close}/>;
        } else {
          return (
            <Fragment key={idx}>
              {loading && (
                <div className="pb4 tc">
                  <toolbox.Asset path="images/spinner.svg"/>
                </div>
              )}
              {!loading && (
                <ProvideVia
                  provider={provider}
                  noManualInvite={[
                    UserProvider.Email,
                    UserProvider.Bitbucket,
                  ].includes(provider)}
                  collaborators={collaborators}
                  onCancel={props.close}
                />
              )}
            </Fragment>
          );
        }
      })}
    </div>
  );
};

interface ProvideViaProps {
  provider: UserProvider;
  collaborators: Collaborator[];
  noManualInvite: boolean;
  onCancel?: (reload: boolean) => void;
}

const ProvideVia = (props: ProvideViaProps) => {
  const config = useContext(Config);

  const [collaborators, setCollaborators] = useState<Collaborator[]>(
    props.collaborators.filter(
      (collaborator) => collaborator.provider === props.provider.toLowerCase()
    )
  );

  const [selectedCollaborators, setSelectedCollaborators] = useState<Collaborator[]>([]);

  const toggleCollaborator = (collaborator: Collaborator) => {
    if (selectedCollaborators.includes(collaborator)) {
      setSelectedCollaborators(
        selectedCollaborators.filter((c) => c !== collaborator)
      );
    } else {
      setSelectedCollaborators([...selectedCollaborators, collaborator]);
    }
  };

  const [newCollaboratorHandle, setNewCollaboratorHandle] = useState(``);

  const [message, setMessage] = useState(``);
  const [loading, setLoading] = useState(false);
  const [anyInvites, setAnyInvites] = useState(false);

  const invite = (collaborators: Collaborator[]) => {
    const invitees = collaborators.map((collaborator) => ({
      uid: collaborator.uid,
      username: collaborator.login,
      invite_email: ``,
      provider: collaborator.provider,
    }));

    setLoading(true);
    void config.inviteMemberUrl
      .call({
        body: {
          invitees,
        },
      })
      .then((resp) => {
        setAnyInvites(true);
        setMessage(resp.data.message);
      })
      .catch((err) => {
        setMessage(err.error as string);
      })
      .finally(() => {
        setLoading(false);
      });
  };

  const newCollaboratorHandleChanged = (handle: string) => {
    setNewCollaboratorHandle(handle);
  };

  const inviteNewUser = () => {
    const collaborator = new Collaborator();

    collaborator.uid = ``;
    collaborator.login = newCollaboratorHandle;
    collaborator.provider = props.provider.toLowerCase();
    setNewCollaboratorHandle(``);

    setCollaborators([collaborator, ...collaborators]);
    toggleCollaborator(collaborator);
  };

  const handleSubmit = (key: string) => {
    if (key == `Enter`) {
      if (newCollaboratorHandle.length == 0) {
        return;
      }

      inviteNewUser();
    }
  };

  if (loading) {
    return (
      <div className="ph4 pb4 tc">
        <toolbox.Asset path="images/spinner.svg"/>
      </div>
    );
  }

  if (message != ``) {
    return (
      <Fragment>
        <div className="ph4 pb4">{message}</div>
        <div className="flex justify-end items-center mt2">
          <button
            className="btn btn-primary ml3"
            onClick={() => props?.onCancel(anyInvites)}
          >
            Done
          </button>
        </div>
      </Fragment>
    );
  }

  return (
    <Fragment>
      <div className="">
        <label className="db mb2">Invite users to join your organization</label>
      </div>
      <div
        className="pv1 ph1 w-100"
        style={{ maxHeight: `400px`, overflow: `auto` }}
      >
        {!props.noManualInvite && (
          <div
            className={`flex items-center jusify-between bg-white shadow-1 ph3 pv2 br3 mb2`}
          >
            <div className="button-group w-100">
              <input
                className="form-control db w-100"
                onInput={(e) =>
                  newCollaboratorHandleChanged(e.currentTarget.value)
                }
                style={{
                  borderBottomRightRadius: `0`,
                  borderTopRightRadius: `0`,
                }}
                onKeyDown={(e) => handleSubmit(e.key)}
                value={newCollaboratorHandle}
                placeholder={`${props.provider} username—`}
              />
              <button
                className="btn btn-secondary"
                disabled={newCollaboratorHandle.length == 0}
                onClick={inviteNewUser}
              >
                Invite
              </button>
            </div>
          </div>
        )}
        {collaborators.length > 0 && (
          <Fragment>
            {collaborators.map((collaborator, idx) => (
              <ActiveShadowDiv
                key={idx}
                className={`flex items-center justify-between bg-white shadow-1 ph3 pv2 br3 mb2 pointer ${
                  selectedCollaborators.includes(collaborator) ? `active` : ``
                }`}
                onClick={() => toggleCollaborator(collaborator)}
              >
                <div className="flex items-center">
                  <input
                    type="checkbox"
                    className="mr3"
                    checked={selectedCollaborators.includes(collaborator)}
                  />
                  {collaborator.hasAvatar() && (
                    <img
                      src={collaborator.avatarUrl}
                      className="w2 h2 br-100 mr2 ba b--black-50"
                    />
                  )}
                  {!collaborator.hasAvatar() && (
                    <div className="w2 h2 br-100 mr2 ba b--black-50 flex items-center justify-center">
                      <b>{collaborator.login.charAt(0).toUpperCase()}</b>
                    </div>
                  )}
                  <div className="flex items-center">
                    <div className="b">{collaborator.displayName}</div>
                    {collaborator.login != `` && (
                      <div className="ml2 f6 gray">@{collaborator.login}</div>
                    )}
                  </div>
                </div>
              </ActiveShadowDiv>
            ))}
          </Fragment>
        )}
      </div>

      {collaborators.length != 0 && (
        <div className="flex justify-end items-center mt2">
          <a
            className="gray underline pointer"
            onClick={() => setSelectedCollaborators(collaborators)}
          >
            Select All
          </a>
          <a
            className="gray underline pointer ml3"
            onClick={() => setSelectedCollaborators([])}
          >
            Select None
          </a>
          <button
            className="btn btn-primary ml3"
            onClick={() => invite(selectedCollaborators)}
            disabled={!selectedCollaborators.length}
          >
            Add selected ({selectedCollaborators.length})
          </button>
        </div>
      )}

      {collaborators.length == 0 && (
        <div className="pv4 tc pb4 mt2">
          <toolbox.Asset
            path="images/ill-girl-showing-continue.svg"
            className="mb2"
          />
          <p className="f6 gray mt3 mb0">
            Looks like everybody is already on Semaphore!
          </p>
        </div>
      )}
    </Fragment>
  );
};

interface ProvideViaEmailProps {
  onCancel?: (reload: boolean) => void;
}

const ProvideViaEmail = (props: ProvideViaEmailProps) => {
  const [state, dispatch] = useReducer(
    PeopleStateReducer,
    new AddPeopleState()
  );
  const config = useContext(Config);

  const peopleToInvite = state.people.filter((person) => !person.isEmpty());
  const arePeopleInvited = peopleToInvite.some((person) => person.wasInvited);

  const people = state.people.filter((person) => {
    if (!arePeopleInvited) {
      return person;
    } else {
      return !person.isEmpty();
    }
  });

  const allPeopleValid = people.every((person) => person.emailValid);

  const updateEmail = (e: ChangeEvent<HTMLInputElement>, person: Person) => {
    if (e.currentTarget.checkValidity()) {
      person.emailValid = true;
      person.email = e.currentTarget.value;
      dispatch({
        type: `UPDATE_PERSON`,
        id: person.id,
        value: person,
      });
    } else {
      person.emailValid = false;
      person.email = e.currentTarget.value;
      dispatch({
        type: `UPDATE_PERSON`,
        id: person.id,
        value: person,
      });
    }
  };

  const updateUsername = (e: ChangeEvent<HTMLInputElement>, person: Person) => {
    person.username = e.currentTarget.value;
    dispatch({
      type: `UPDATE_PERSON`,
      id: person.id,
      value: person,
    });
  };

  const save = () => {
    peopleToInvite.forEach((person) => {
      person.setLoading();
      config.createMemberUrl
        .call({
          body: { email: person.email, name: person.username },
        })
        .then((resp) => {
          const hasError = !_.isEmpty(resp.error);
          const hasPassword = !_.isEmpty(resp.data.password);

          if (hasError) {
            person.setError(resp.error);
            dispatch({
              type: `UPDATE_PERSON`,
              id: person.id,
              value: person,
            });
            return resp;
          }

          if (!hasPassword) {
            person.setError(resp.data.message);
            dispatch({
              type: `UPDATE_PERSON`,
              id: person.id,
              value: person,
            });
            return resp;
          }

          person.setPassword(resp.data.password);
          dispatch({
            type: `UPDATE_PERSON`,
            id: person.id,
            value: person,
          });
          return resp;
        })
        .catch((err) => {
          person.setError(err.error as string);
          dispatch({
            type: `UPDATE_PERSON`,
            id: person.id,
            value: person,
          });
        });
    });
  };

  return (
    <Fragment>
      <div className="ph1" style={{ maxHeight: `400px`, overflow: `auto` }}>
        {!arePeopleInvited && (
          <label className="db mb2">Email addresses and usernames</label>
        )}
        {arePeopleInvited && (
          <Fragment>
            <label className="db mb2">Users created successfully</label>
            <p className="mb3">
              The following users have been created and added to the
              organization. Make sure to securely share their temporary,
              one-time passwords.
            </p>
          </Fragment>
        )}
        {people.map((person) => (
          <div key={person.id} className="email-input-group mb3">
            {person.state == PersonState.Empty && (
              <div className="flex">
                <div className="flex-auto mr2">
                  <input
                    type="email"
                    className={`form-control w-100 ${
                      person.emailValid ? `` : `ba b--red`
                    }`}
                    placeholder="Enter email address"
                    value={person.email}
                    onInput={(e) => updateEmail(e, person)}
                  />
                </div>
                <div className="flex-auto">
                  <input
                    type="text"
                    className="form-control w-100"
                    placeholder="Username (optional)"
                    value={person.username}
                    onInput={(e) => updateUsername(e, person)}
                  />
                </div>
              </div>
            )}
            {person.state == PersonState.Invited && (
              <div className="mb3 pa3 bg-white shadow-1 br2">
                <div className="flex items-center justify-between mb2">
                  <div>
                    <span className="f4">{person.email}</span>
                    <span className="ml2 f5 gray">{person.username}</span>
                  </div>
                </div>
                <div className="bg-washed-yellow pa2 br2">
                  <div className="flex items-center justify-between">
                    <span className="gray">Temporary password:</span>
                    <code className="f6">{person.password}</code>
                  </div>
                </div>
              </div>
            )}
            {person.state == PersonState.Loading && (
              <div className="mb3 pa3 bg-white shadow-1 br2">
                <div className="flex items-center justify-center mv2">
                  <toolbox.Asset path="images/spinner.svg"/>
                </div>
              </div>
            )}
            {person.state == PersonState.Error && (
              <div className="mb3 pa3 bg-washed-red shadow-1 br2">
                <div className="bg-washed-red pa2 br2">
                  <div className="flex flex-column justify-between">
                    <span className="red">
                      Failed creating {person.username}&lt;
                      <b>{person.email}</b>&gt;
                    </span>
                    <code className="f6">{person.errorMessage}</code>
                  </div>
                </div>
              </div>
            )}
          </div>
        ))}
      </div>
      {arePeopleInvited && (
        <div className="flex justify-end">
          <button
            className="btn btn-primary"
            onClick={() => props?.onCancel(true)}
          >
            Done
          </button>
        </div>
      )}
      {!arePeopleInvited && (
        <div className="flex justify-end">
          <button
            className="btn btn-secondary mr3"
            onClick={() => props?.onCancel(false)}
          >
            Cancel
          </button>
          <button
            className="btn btn-primary"
            onClick={save}
            disabled={!allPeopleValid}
          >
            Create Accounts
          </button>
        </div>
      )}
    </Fragment>
  );
};


const ActiveShadowLink = styled.button`
  &:hover,
  &.active {
    z-index: 2;
    box-shadow: 0 0 0 3px #00359f !important;
  }
`;

const ActiveShadowDiv = styled.div`
  &:hover,
  &.active {
    z-index: 2;
    box-shadow: 0 0 0 3px #00359f !important;
  }
`;
