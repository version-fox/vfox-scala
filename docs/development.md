# Development

[中文](zh-CN/development.md) | [English](development.md)

## Layout

```
.devcontainer/                the development container for Linux hosts, with the tools the workflows pin
metadata.lua                  plugin name, version and the notes that vfox add prints
hooks/available.lua           vfox search: the download list of scala-lang.org
hooks/pre_install.lua         vfox install: the download address and its checksum
hooks/env_keys.lua            SCALA_HOME and PATH
hooks/detect.lua              vfox link --detect scala: the Scala already on the machine
hooks/post_install.lua        nothing to do
hooks/pre_use.lua             nothing to do
lib/util.lua                  versions, download addresses, the archive of a version, checksums
lib/detect_scala.lua          finding Scala homes and their versions
tests/*_test.lua              offline hook tests, run by vfox plugin test
tests/e2e/                    end-to-end suites in Go, see e2e.md
Injection.lua                 type hints for what vfox injects, never loaded
README.md, README_CN.md, docs/
                              the documentation; docs/zh-CN/ holds the Chinese pages
opencode.jsonc                lets OpenCode agent sessions in this repository run git push, gh pr create and gh pr comment without asking
```

vfox loads `metadata.lua`, calls a hook when a command needs it, and puts `PLUGIN` and `RUNTIME` (`osType`, `archType`, `version`) in scope. `osType` and `archType` are Go's `GOOS` and `GOARCH` of the vfox binary, so the values are `windows`, `linux` and `darwin`.

## What runs for a command

| You run | Hooks |
| --- | --- |
| `vfox search scala` | `Available` |
| `vfox install scala@3.10.1` | `PreInstall` returns the URL and, from GitHub, the checksum. vfox downloads and unpacks |
| `vfox use scala@3.10.1` and `vfox exec` | `EnvKeys` provides `SCALA_HOME` and `PATH` |
| `vfox link --detect scala` | `Detect` returns the Scala installations already on the machine (`lib/detect_scala.lua`) |

A few contracts that cost time to find:

- `PreInstall` returns a table. `version` names the install, `url` is what vfox downloads, and a checksum goes under the name of its algorithm, `sha256` here. Without a `sha256` key vfox warns and installs.
- `Available` returns a table of `{ version, note }`. The note is `LTS` for a long-term support release, and the version has no note in its name: the list shows `Scala 3.9.0 LTS`, the plugin returns `3.9.0` with the note `LTS`. A `3.9.0 LTS` version installs nothing.
- `EnvKeys` reads the install directory from `ctx.main.path` on vfox 1.x and from `ctx.path` on the older contract. Both are read.
- `Detect` returns `{ version, path, note }`, one entry per version, so the same Scala reached through two paths is offered once.
- `Available` raises an error when the download list cannot be read. It does not return an empty list, which would look like Scala had no releases.
- `RUNTIME.osType` is `windows` on Windows, so the Windows branches compare with that spelling.

## Versions and downloads

`lib/util.lua` decides where a version comes from. The table and the reasons are in [versions.md](versions.md). In short, Scala 3 and 2.11 and later come from GitHub, and earlier releases are on scala-lang.org, where the download page of the version names the archive. `util.source_of` is the one place that makes the choice; the other functions take its answer.

The checksum comes from a `.sha256` file next to a GitHub download, when there is one. `util.parse_sha256` reads only a 64-digit SHA-256; anything else is ignored.

## Detecting installed Scala

`hooks/detect.lua` hands the work to `lib/detect_scala.lua`. Its roots and the order in which it reads a version are in [detect.md](detect.md). The Windows roots use `dir /b` and the Unix roots use `ls -1`, and `io.popen` runs `scala -version` only for a home that the names and jars leave unversioned.

## Tests

The offline tests run under `vfox plugin test`, which vfox 1.0.13 and later has. It finds every `tests/**/*_test.lua` and runs each file in a VM of its own, so a new test file needs no entry anywhere:

```bash
vfox plugin test .
vfox plugin test . --file tests/util_test.lua
```

Run it from the repository root. The Test Plugin workflow installs vfox 1.1.0, pinned in `.github/workflows/test.yml`, because `vfox link --detect` needs it. Use the same release locally.

A test file calls `test.load()` from `vfox.test` and then calls the hooks through what it returns, as in `plugin:PreInstall({ version = "3.10.1" })`. `test.load` takes the platform (`os`, `arch`), the environment variables (`env`) and a function that answers every HTTP request (`http`). `RUNTIME.osType` can be set to try another platform. The VM disables `io.popen` and `os.execute`, so the scanner tests replace `io.open` and `io.popen` with a fake file system, as `tests/detect_test.lua` does.

When a new check needs a page or a file from the network, its answer goes into the test as it was served on the day it was read, with the date, as `tests/available_test.lua` and `tests/util_test.lua` do.

## Lint, format and license checks

Run these from the repository root. They are the same commands the workflows run.

```bash
# Lua
stylua --check .
lua-language-server --check . --checklevel=Warning

# Go, in tests/e2e
(cd tests/e2e && test -z "$(gofmt -l .)" && go vet ./... && GOOS=windows go vet ./... && go test -short ./...)

# Workflows
go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.12

# License headers
license-eye header check
```

`license-eye` is Apache SkyWalking Eyes; the Docker form is in [e2e.md](e2e.md#local-checks). Every Lua, Go, YAML, TOML, JSONC and Dockerfile file starts with the Apache 2.0 header of `.licenserc.yaml`. Markdown and JSON files are not checked.

To format Lua, run `stylua .` with the version the workflow pins, since the output of stylua changes between versions.

## Releasing

A maintainer publishes from **Actions → Plugin → Run workflow** on the default branch, entering a stable plugin version without the `v` prefix. The shared workflow, [plugin-manifest-action](https://github.com/version-fox/plugin-manifest-action), updates `metadata.lua`, creates the version commit and the tag, and publishes the ZIP and the manifest in this repository. No local tag or extra release token is needed. Pull requests run the checks only.

Pushing a version tag publishes too, when `PLUGIN.version` already matches the tag. If publication fails, re-run the failed job to resume it. The workflow follows the shared `@v1` release tool, and updating the tool does not release this plugin.

Changes that are not released yet sit under "Unreleased" ("未发布" in Chinese) in [changes.md](changes.md). When a release is out, move them under its version and date, in both languages.

## Writing the docs

English pages are in `docs/`, the Chinese ones in `docs/zh-CN/` under the same names, and the Chinese README is `README_CN.md`. Each page starts with a link to the other language. A new page goes into the Documentation list of both READMEs.
