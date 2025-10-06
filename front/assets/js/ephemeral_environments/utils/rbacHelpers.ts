import * as types from "../types";

export const SUBJECT_TYPE_OPTIONS = [
  { value: `user` as types.RBACSubjectType, label: `User` },
  { value: `group` as types.RBACSubjectType, label: `Group` },
  { value: `service_account` as types.RBACSubjectType, label: `Service Account` },
];

export function getSubjectIcon(type: types.RBACSubjectType): string {
  switch (type) {
    case `user`:
      return `person`;
    case `group`:
      return `group`;
    case `service_account`:
      return `smart_toy`;
    default:
      return `help`;
  }
}

export function getSubjectTypeLabel(type: types.RBACSubjectType): string {
  switch (type) {
    case `user`:
      return `User`;
    case `group`:
      return `Group`;
    case `service_account`:
      return `Service Account`;
    default:
      return type;
  }
}

export function groupSubjectsByType(subjects: types.RBACSubject[]): Record<types.RBACSubjectType, types.RBACSubject[]> {
  const grouped: Record<types.RBACSubjectType, types.RBACSubject[]> = {
    user: [],
    group: [],
    service_account: [],
  };

  subjects.forEach((s) => {
    if (grouped[s.type]) {
      grouped[s.type].push(s);
    }
  });

  return grouped;
}
