export const REPOSITORY_SLUG_REGEX = /^[A-Za-z0-9][A-Za-z0-9-]*\/[A-Za-z0-9._-]+$/;

export const parseRepositorySlug = (query: string): string | null => {
  const trimmed = query.trim();
  return REPOSITORY_SLUG_REGEX.test(trimmed) ? trimmed : null;
};
