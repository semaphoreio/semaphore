
# How to use Docusaurus versioning

We use [versioning] on Docusaurus to maintain the Cloud, CE and EE editions of Semaphore. Each version consists of a different set of pages and sidebars as the features and capabilities change.

This page describes how to create a new version or release.

## Overview

We handle docs in two ways:

- Cloud: the cloud edition is unversioned. The docs are located on `docs/`
- Community Edition: the open-source edition is versioned. The docs are located on `versioned_docs/version-CE/`
- Enterprise Edition: the licensed on-premise is also versioned. The docs are located on `versioned_docs/version-EE/`

## Naming conventions

Each versioned doc must have a unique ID string to identify the set of pages. We use the following conventions

### Community Edition

The latest version ID is always "CE" (without the semver). Older versions have the semver appended.

For example:

- Latest version: "CE" (could be v2.0 or greater)
- Version 1.0: "CE-1.0"
- Version 1.1: "CE-1.1"

When a new version is released, update the version number on `docusaurus.config.js`

```js
    "CE": {
      label: 'Community Edition (1.1)',
      path: 'CE',
      banner: "none"
    }
```

### Enterprise Edition

The latest version ID is always "EE" (without the semver). Older versions have the semver appended.

For example:

- Latest version: "EE"
- Version 1.0: "EE-1.0"
- Version 1.1: "EE-1.1"

## How to create a new version of the docs

The following example assumes we're creating a new CE version 1.1 docs

### Step 1: Copy versioned docs and sidebars

Rename the latest edition by appending the semver

```shell
mv versioned_docs/version-CE versioned_docs/version-CE-1.0
mv versioned_sidebars/version-CE-sidebars.json versioned_sidebars/version-CE-1.0-sidebars.json
```

### Step 2: Create the current copy of the docs

Copy the 1.0 version of the docs as the latest release. This is your starting point.

```shell
cp -r versioned_docs/version-CE-1.0 versioned_docs/version-CE
cp versioned_sidebars/version-CE-1.0-sidebars.json versioned_sidebars/version-CE-sidebars.json
```

Add the new version to `versions.json`. Add the newer version ID at the top.

## Step 3: Edit versions.json

Add the older (1.0) version to `versions.json`. Starting from most current to older versions

```json
[
  "CE",
  "CE-1.0"
]
```

## Step 4: Edit docusaurus.config.json

Go to the `presets` section in the page and add an entry for the 1.0 version. 

For example, before adding the new version, the section may look like this:

```js
    lastVersion: 'current',
    versions: {
    current: {
        label: 'Semaphore Cloud',
        path: '',
        banner: "none"
    },
    "CE": {
        label: 'Community Edition (1.0)',
        path: 'CE',
        banner: "none"
    }
    },
```

To add a new version: 
- Bump the `label` of the `CE` entry
- Add a new `CE-1.0` key
- remove the `banner` line in all but the most recent version for Semaphore edition, the banner is used to warn the user that they are browsing an older release

After adding the new version, the config looks like this:

```js
    lastVersion: 'current',
    versions: {
    current: {
        label: 'Semaphore Cloud',
        path: '',
        banner: "none"
    },
    "CE": {
        label: 'Community Edition (1.1)',
        path: 'CE',
        banner: "none"
    },
    "CE-1.0": {
        label: 'Community Edition (1.0)',
        path: 'CE-1.0',
    }
    },
```

### Step 5: Edit your docs

In the newly-created docs and sidebars for the `CE` edition. You can create new pages, add notices of deprecation, update the changelog, etc.

Tip: Use relative paths to keep versions separated.

## Step 6: Test your build

Run the following commands to test your build:

```shell
npm run lint
npm run build
npm run serve
```

Open a browser and check that the dropdown works and the new version is working.

## How to remove versions

To remove old versions, follow these steps:

- Delete the folder in `versioned_docs`
- Delete the sidebar in `veersioned_sidebars`
- Remove the entry on `versions.json`
- Remove the entry on `docusaurus.config.json`

## How to handle unavailable features

We should make it clear when a feature is not available in one Semaphore edition.

There are two options to deal with unavailable versions:

1. Delete the content: delete the content from the version
2. Mark it as unavailable: keep the title or subheader but clearly mark it as unavailable. Add links to other editions where the feature is available

As a general rule, we should make it clear when a feature is unavailable, especially for very prominent features such as Promotions, RBAC, or other enterprise-grade features.

### How to manage pages missing in editions

For features that have a whole page dedicated, e.g. Promotions, do the following:

1. Add `displayed_sidebar: <sidebarID>` to the frontmatter of the page. This will prevent the sidebar from disappearing. Refer to `sidebars.js` to get the value of the `sidebarID`.

    For example:

    ```md
    ---
    description: Connect pipelines to create workflows
    displayed_sidebar: usingSemaphore
    ---
    ```

2. Add the `FeatureNotAvailable` Component. This will add a banner on the top of the page that marks the feature as not available and link to other editions.

    ```md
    import FeatureNotAvailable from '@site/src/components/FeatureNotAvailable';
    <FeatureNotAvailable/>
    ```

3. Remove/edit all other contents in the page
4. Remove the entry from the sidebar:
   - For explicit items in sidebar file, remove the in the corresponding file in the `versioned_sidebars` folder
   - For autogenerated docs, add `sidebar_class_name: hidden` into the doc frontmatter


