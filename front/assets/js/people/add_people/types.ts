import _ from "lodash";

export enum UserProvider {
  Email = `email`,
  GitHub = `github`,
  Bitbucket = `bitbucket`,
  GitLab = `gitlab`,
}

export class Collaborator {
  displayName: string;
  uid: string;
  login: string;
  provider: string;
  avatarUrl: string;

  constructor() {
    this.displayName = ``;
    this.uid = ``;
    this.login = ``;
    this.provider = ``;
    this.avatarUrl = ``;
  }

  static fromJSON(json: any): Collaborator {
    const collaborator = new Collaborator();
    collaborator.displayName = json.display_name as string;
    collaborator.login = json.login as string;
    collaborator.uid = json.uid as string;
    collaborator.provider = json.provider as string;
    collaborator.avatarUrl = json.avatar_url as string;

    return collaborator;
  }

  hasAvatar(): boolean {
    return this.avatarUrl.length != 0;
  }
}

export enum PersonState {
  Empty,
  Loading,
  Invited,
  Error,
}

export class Person {
  id: string;
  email: string;
  username: string;
  password = ``;
  errorMessage = ``;
  state: PersonState = PersonState.Empty;
  wasInvited: boolean;
  emailValid = true;

  constructor() {
    this.id = _.uniqueId(`person_`);
    this.email = ``;
    this.username = ``;
    this.wasInvited = false;
  }

  isEmpty(): boolean {
    return _.isEmpty(this.email) && _.isEmpty(this.username);
  }

  init() {
    this.password = ``;
    this.errorMessage = ``;
    this.state = PersonState.Empty;
  }

  setPassword(password: string) {
    this.state = PersonState.Invited;
    this.password = password;
  }

  setError(errorMessage: string) {
    this.state = PersonState.Error;
    this.errorMessage = errorMessage;
  }
  setLoading() {
    this.wasInvited = true;
    this.state = PersonState.Loading;
  }
}

export class AddPeopleState {
  people: Person[] = [new Person()];
  type: UserProvider;
}

export type AddPeopleAction =
  | { type: `UPDATE_PERSON`, id: string, value: Person, }
  | { type: `REMOVE_PERSON`, id: string, }
  | { type: `RESET`, };

export const PeopleStateReducer = (
  state: AddPeopleState,
  action: AddPeopleAction
) => {
  switch (action.type) {
    case `UPDATE_PERSON`: {
      const newPeople = state.people
        .map((person) => {
          if (person.id == action.id) {
            return action.value;
          }
          return person;
        })
        .filter((person) => !person.isEmpty());

      newPeople.push(new Person());

      return { ...state, people: newPeople };
    }

    case `REMOVE_PERSON`: {
      const newPeople = state.people.filter((person) => person.id != action.id);

      return { ...state, people: newPeople };
    }

    case `RESET`: {
      return { ...state, people: [new Person()] };
    }

    default:
      return state;
  }
};

export const AvailableProviderTypes: UserProvider[] = [
  UserProvider.Email,
  UserProvider.GitHub,
  UserProvider.Bitbucket,
  UserProvider.GitLab,
];
