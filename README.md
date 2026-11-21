# vfox-scala

[中文](README_CN.md) | [English](README.md)

Scala plugin for [vfox](https://vfox.dev/).

It installs Scala 3 and Scala 2 releases, from GitHub for 2.11 and later and for 2.10.5 to 2.10.7, and from scala-lang.org for the older ones, and checks a download against the SHA-256 that Scala publishes for it where there is one. It also finds Scala that is already on the machine and links it, so you can use it through vfox without a second download.

## Install

After installing [vfox](https://github.com/version-fox/vfox), add the plugin, install a version and select it:

```bash
vfox add scala
vfox install scala@3.10.1
vfox use --global scala@3.10.1
scala -version
```

`scala -version` shows the version that is selected. For `scala` to be on the `PATH`, vfox has to be hooked into your shell, see its [quick start](https://vfox.dev/guides/quick-start.html). Scala runs on a Java runtime, which must be installed separately.

`vfox search scala` lists the releases.

## Versions

A version is written as Scala releases it, such as `3.10.1`, `2.13.18`, `2.10.4` or `2.7.7.final`. Release candidates and milestones keep their suffix, as in `3.0.0-RC1`. The long-term support releases carry the note `LTS` in `vfox search`.

```bash
vfox install scala@3.10.1       # verified against its published SHA-256
vfox install scala@2.13.18      # from GitHub
vfox install scala@2.10.4       # from the scala-lang.org archive
vfox exec scala@3.10.1 -- scalac -version
```

[docs/versions.md](docs/versions.md) says where each version is downloaded from, and when a checksum is checked.

## Scala already on the machine

`vfox link --detect scala` looks for Scala installations that vfox did not install: `SCALA_HOME`, SDKMAN, asdf, mise, Homebrew, Scoop, the system directories and Program Files. It asks which ones to link, or links all of them with `--yes`. It needs vfox 1.1.0 or later.

```bash
vfox link --detect scala --yes
vfox exec scala@2.12.20 -- scala -version
```

[docs/detect.md](docs/detect.md) lists where it looks and how it reads each version.

## Documentation

- [Versions](docs/versions.md): where each version comes from, and the checksums.
- [Finding Scala already on the machine](docs/detect.md)
- [Changes](docs/changes.md)
- [Development](docs/development.md): the layout, the hooks, the tests and the checks.
- [E2E](docs/e2e.md): the end-to-end suites for Linux and Windows.

## Releasing

Maintainers publish from the Plugin workflow, as described in [docs/development.md](docs/development.md#releasing).

## License

Apache License 2.0, see [LICENSE](LICENSE).
