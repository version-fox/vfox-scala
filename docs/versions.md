# Versions

[中文](zh-CN/versions.md) | [English](versions.md)

This page says what `vfox search scala` lists, where each version is downloaded from, and how the download is checked.

## Names

A Scala version is written as it is released: `3.10.1`, `2.13.18`, `2.10.4`, `2.7.7.final`. Release candidates and milestones keep their suffix, such as `3.0.0-RC1` or `2.13.0-M5`.

`vfox search scala` reads the download list of [scala-lang.org](https://www.scala-lang.org/download/all.html). Long-term support releases carry the note `LTS`:

```text
3.9.0    LTS
3.10.1
```

The list is newest first, as the page has it.

## Where a version is downloaded from

The source depends on the version. Windows takes the zip everywhere; Linux and macOS take the tar.gz or tgz.

| Versions | Source | Linux and macOS | Windows |
| --- | --- | --- | --- |
| 3.0.0 and later, release candidates included | GitHub, [scala/scala3](https://github.com/scala/scala3/releases) | `scala3-<version>.tar.gz` | `scala3-<version>.zip` |
| 2.11.0 and later, release candidates and milestones included | GitHub, [scala/scala](https://github.com/scala/scala/releases), tag `v<version>` | `scala-<version>.tgz` | `scala-<version>.zip` |
| Before 2.11.0, down to 2.5.0 | [scala-lang.org](https://www.scala-lang.org/download/all.html), the archive that each version's download page links | `.tar.gz` or `.tgz`, as the page names it | `.zip` |

The archive releases do not follow one naming pattern (`scala-2.7.0-final.tar.gz`, `scala-2.7.7.final.tgz`, `scala-2.10.4.tgz`), so the plugin reads the archive from the download page of the version it installs. A page that lists no archive for the platform stops the install with the page's address.

Before this release, the plugin asked `downloads.lightbend.com` for versions from 2.10.4 to 2.13.x, which answered 403. Versions from 2.11 on now come from GitHub.

## Checksums

vfox checks a download against a SHA-256 digest when the plugin gives it one. For a GitHub release the plugin looks for a `.sha256` file next to the download, which Scala publishes for some releases (3.10.1 has one, 3.5.0 does not). Without one vfox prints:

```text
WARNING: Checksum is not provided, skip verify...
```

and installs the download anyway. A digest that cannot be read is treated the same way, so a missing checksum file does not stop an install. Releases on scala-lang.org get no checksum from the plugin.

## Installing and using

```bash
vfox install scala@3.10.1       # Scala 3, verified against its published checksum
vfox install scala@2.13.18      # Scala 2.13, from GitHub
vfox install scala@2.10.4       # Scala 2.10, from scala-lang.org
vfox use --global scala@3.10.1
vfox exec scala@3.10.1 -- scalac -version
```

`EnvKeys` sets `SCALA_HOME` to the installed Scala and puts its `bin` folder on the `PATH`.

The checks of this repository install one release from the archive (2.10.4) and do not run it. See [e2e.md](e2e.md#what-the-suites-check).
