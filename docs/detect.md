# Finding Scala already on the machine

[中文](zh-CN/detect.md) | [English](detect.md)

`vfox link --detect scala` looks for Scala installations that vfox did not install, and links the ones it finds, so a Scala you already have can be used through vfox without a second download. It needs vfox 1.1.0 or later.

```bash
vfox link --detect scala        # asks which ones to link
vfox link --detect scala --yes  # links everything it finds
```

Each one is linked under the version it names, and then works like an installed version:

```bash
vfox exec scala@2.12.20 -- scala -version
```

## Where it looks

The folders directly under each root are checked, and `SCALA_HOME` is checked as a home itself. A folder is a Scala only if it is a Scala home (see below).

| Platform | Root | What it covers |
| --- | --- | --- |
| all | `$SCALA_HOME` | the folder it names, which may be the home itself |
| Linux and macOS | `~/.sdkman/candidates/scala` | SDKMAN |
| Linux and macOS | `~/.asdf/installs/scala`, `~/.local/share/mise/installs/scala` | asdf and mise |
| Linux and macOS | `/opt/homebrew/opt`, `/usr/local/opt` | Homebrew kegs whose name contains `scala` |
| Linux and macOS | `/home/linuxbrew/.linuxbrew/opt`, `~/.linuxbrew/opt` | Linuxbrew kegs whose name contains `scala` |
| Linux and macOS | `/opt`, `/usr/local`, `/usr/local/share`, `/usr/share`, `/usr/lib` | folders whose name contains `scala`, such as `/opt/scala-2.13.18` |
| Windows | `%USERPROFILE%\.asdf\installs\scala`, `%USERPROFILE%\.local\share\mise\installs\scala` | asdf and mise |
| Windows | `%USERPROFILE%\scoop\apps\scala` | Scoop, which keeps one folder per version beside `current` |
| Windows | `%ProgramFiles%` and `%ProgramFiles(x86)%` | folders whose name contains `scala` |

Folders that vfox manages, whose path has a `.vfox` folder in it, are never reported.

## What makes a Scala home

A Scala home is a folder with a `bin/scala` launcher, or `bin\scala.bat` on Windows. A Homebrew keg keeps the distribution in `libexec`, so the plugin also accepts `libexec/bin/scala`.

## Where the version comes from

The version is taken from the first of these that gives one:

1. The `VERSION` file of a Scala 3 distribution, which holds the line `version:=3.5.0`.
2. The jar names in `lib`: `scala3-library_3-<version>.jar`, then `scala-library-<version>.jar`. Scala 3 also ships a Scala 2 library, so its own runtime is preferred.
3. The name of the folder, when it is a full version: `scala-2.13.18`, `scala3-3.5.0` or `2.13.18`. A name with only a major and minor number, such as Debian's `scala-2.12`, is not enough.
4. The output of `scala -version`, which needs a Java runtime. Scala 2 prints `Scala code runner version 2.13.18`, and Scala 3 prints `Scala version (default): 3.5.0`.

A Scala with none of these is not reported. A Scala 2 distribution keeps its jars unversioned, so the folder name or the launcher decides for it.

## One entry per version

When two folders hold the same version, for example SDKMAN's `3.5.0` and its `current` link, one entry is kept: the path that sorts first. Each entry is `{ version, path, note }`, where the note names the root it was found under, such as `installed by SDKMAN` or `system Scala`.

## Testing it

The offline tests in `tests/detect_*_test.lua` run the scanner on a fake file system, for the Linux and Windows roots, including a Linuxbrew keg and Scoop. The macOS roots, such as `/opt/homebrew/opt`, share the code path of the Linux ones but have no test of their own. The end-to-end suites install a Scala by hand outside vfox and check that `vfox link --detect` finds and links it, see [e2e.md](e2e.md#what-the-suites-check).
