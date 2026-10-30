# Releasing Clearport

Clearport has two separate workflows:

- Every push to `main` builds, checks, and uploads a test APK as a GitHub Actions artifact. It does not publish or replace a GitHub Release.
- A version tag is the only trigger that publishes a public GitHub Release.

## Publish a version

First make sure the changes you want to release are merged into `main`. Then, from your local repository, run:

```bash
git switch main
git pull
git tag v1.0.3
git push origin v1.0.3
```

Replace `v1.0.3` with the next version number.

GitHub Actions will then run the release workflow, install dependencies, analyze and test the project, build and verify the APK, and publish a GitHub Release with the APK and generated release notes.

Do not create the tag until the version is ready to publish. Each version tag should be new and should never be reused.

## Get the latest development APK

For a build that is not being published as a version, open the **Build APK** workflow in GitHub Actions, select the latest successful run on `main`, and download the `clearport-apk` artifact. These workflow artifacts are retained for 30 days.
