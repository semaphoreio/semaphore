# Repository Guidelines

## Project Structure & Module Organization

The docs site runs on Docusaurus. Author new or updated guides in `docs/` and keep contributor-facing notes in `docs-contributing/`. Historical content lives in `versioned_docs/`, paired with `versioned_sidebars/` for navigation metadata. Custom React or styling tweaks reside in `src/` (`components/`, `pages/`, `theme/`), while shared assets such as images, downloads, and redirects belong under `static/`. Park work-in-progress material inside `docs-drafts/` to prevent accidental publication.

## Build, Test, and Development Commands

Run `npm start` (or `make npm.dev`) to spin up the live-reloading docs server on `localhost:3000`. `npm run build` (mirrored by `make npm.build`) generates the production-ready static bundle in `build/` and surfaces MDX or sidebar errors. Enforce content quality with `npm run lint` or `make npm.lint`, which executes `markdownlint-cli2` across `docs/**` and `versioned_docs/**`.

```bash
npm run lint
```

Ensure `npm run build` exits without error before committing any changes.

## Coding Style & Naming Conventions

Use YAML front matter with at least `title` and `description` (and `slug` or `sidebar_position` when needed) to keep navigation orderly. Write concise Markdown/MDX in sentence case headings, wrap prose near 100 characters to ease reviews, and prefer lists or tables for procedural steps. Tag code fences with a language hint and surface commands with shell blocks. Name reusable MDX components in PascalCase and place them under `src/components/`, and store shared assets in kebab-case filenames (for example `rolling-deploy.png`).

Further coding and style guidelines are stated on `docs-contributing/STYLE_GUIDE.md`

## Testing Guidelines

Run `npm run lint` before pushing; suppress rules only when `.markdownlint.json` documents the exception. Follow with `npm run build` to catch broken imports, invalid images, or sidebar regressions. For parity with containerized checks, `make test` executes the nginx configuration validation used in CI.

## Commit & Pull Request Guidelines

Use the Conventional Commits style seen in history—`docs(scope): concise summary`—to keep automation predictable. Reference issues or Linear tickets in the body, describe the user-facing impact, and call out the docs sections affected. Include screenshots or GIFs when the UI or illustrations change, and add deploy preview URLs so reviewers can validate navigation, search, and syntax highlighting interactively.

## Versioning

The versioning schema for new releases in the `versioned_docs` and `versioned_sidebars` as detailed in the `docs-contributing/VERSIONING.md`.
