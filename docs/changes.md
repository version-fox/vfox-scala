# Changes

[中文](zh-CN/changes.md) | [English](changes.md)

What changed in each release, as a user notices it. GitHub's release pages list the pull requests. The releases before this list were not described here.

## Unreleased

- `vfox install scala@3.0.0`, and the Scala 3 release candidates such as `3.0.0-RC1`, asked GitHub for a `.tgz` that Scala 3 does not publish, so the download failed with a 404. They are `.tar.gz` now, and `.zip` on Windows. See [versions.md](versions.md#where-a-version-is-downloaded-from).
- Scala 2.10.4 and the Scala 2.11 to 2.13 releases asked `downloads.lightbend.com` for their files, which answered 403, so they did not install. Scala 2.11 and later come from GitHub now, and 2.10.4 and the releases before 2.11 from the archive that each version's download page links: on scala-lang.org, or on GitHub for 2.10.5 to 2.10.7. See [versions.md](versions.md#where-a-version-is-downloaded-from).
- `vfox install scala@2.5.0.final` asked `downloads.lightbend.com` for its file too, and not the scala-lang.org archive that has it. It comes from the archive now.
- `vfox search scala` offered `3.9.0 LTS` as the version name, which installs nothing. The version is `3.9.0`, with the note `LTS`. `vfox install scala@"3.9.0 LTS"` is refused now, as a name with a space is not a version.
- `vfox search scala` printed `nil` on every run. A failed read of the download list returned an empty list, which looked like Scala had no releases. A failed read is an error now, with the status code, and so is a page that lists no version.
- The version comparison dropped every part of a version that is not a number, so `3.0.0-RC1` and `2.13.0-M5` were routed as if they were final releases. Versions are routed by their numbers now, and the suffix is kept.
- The checksum that Scala publishes next to a GitHub download is checked, where there is one: `Verifying checksum` appears in the output of `vfox install scala@3.10.1`. Without one, vfox warns as before.
- `vfox link --detect scala` finds the Scala installations that are already on the machine, and links them. It needs vfox 1.1.0 or later. See [detect.md](detect.md).
- Documentation in English and Chinese: versions, detection, development, the end-to-end suites and this page.
- Checks on every change: stylua and LuaLS for Lua, gofmt, vet and unit tests for the end-to-end suites, actionlint for the workflows, the license headers, the offline hook tests under `vfox plugin test`, and the end-to-end suites on Linux (Docker) and Windows. See [e2e.md](e2e.md).
