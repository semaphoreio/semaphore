## Releases

### Creating a new minor release

1. Create release branch. The release branch name follows the pattern `release/vX.Y.x`, where `X` is the major version and `Y` is the new minor version. For example, when releasing a new `v1.0.0` version, we'd create the release branch `release/v1.0.x`.

```bash
git checkout main
git pull origin main
git checkout -b release/v1.0.x
git push origin release/v1.0.x
```

2. Update the `change_in` directives for the new release branch. There's an easy one-liner for that [here](#update-change_in-directives). Since the release branch is protected, you'll need a PR for updating it with those changes.

3. Start the ephemeral environment and run the E2Es on it. If the E2Es are not green, you need to fix them before proceeding.

4. If E2Es are green, tag the release branch:

```bash
git checkout release/v1.0.x
git pull origin release/v1.0.x
git tag v1.0.0
git push origin v1.0.0
```

1. Use the "Generate Helm chart" and "Release" promotions to create a new Helm chart and push it to a release in GitHub.

2. After the release is published, generate the changelog for it and add it in the release description. Details for that are [here](#generate-changelog).

#### Update change_in directives

You can use [yq](https://mikefarah.gitbook.io/yq) to update all `change_in` directives in the Semaphore YAML:

```bash
yq e -i '(.blocks.[].run.when) |= (. | sub("main", "release/1.0.x"))' .semaphore/semaphore.yml
```

#### Generate changelog

Use [git-cliff](https://github.com/orhun/git-cliff), using the previous release tag and this one:

```bash
git-cliff <previous-version>..v1.0.0
```

A few notes here:
- You will need to review the changes and make sure they are appropriate. We are not enforcing conventional commits yet, so some changes might not be included.
- If there are breaking changes, include a section at the beginning of the changelog detailing the breaking changes.
- If the upgrade process requires any attention, include a section for it as well.