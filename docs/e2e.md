# E2E

[中文](zh-CN/e2e.md) | [English](e2e.md)

The end-to-end suites run the real vfox 1.1.0 against this plugin, which is packed into a zip the way `vfox add --source` takes it, and against the real download servers. The offline tests in `tests/*_test.lua` run in the **Test Plugin** workflow and need no network; see [development.md](development.md#tests).

| Suite | Where it runs | Isolation |
| --- | --- | --- |
| `tests/e2e/linux` | Docker containers, from the image built from `tests/e2e/linux/Dockerfile` | one new container per group of checks, removed afterwards |
| `tests/e2e/windows` | the host of a Windows machine, with `vfox.exe` from its release | one new `VFOX_HOME` and folders per group, under a temporary folder |

Both suites are Go programs with the standard library only, in the module `tests/e2e`. The checks themselves are in `tests/e2e/common`, and each platform package only decides where vfox runs. CI runs the Linux suite on `ubuntu-latest` and the Windows suite on `windows-latest` (the **E2E** workflow).

## What the suites check

Each suite has two groups, and the groups share one flow of checks (`common.CheckInstallAndRun` and `common.CheckArchiveAndDetect`).

**Install and run** adds the plugin from the zip, then:

1. `vfox info scala` prints the note that links to the README.
2. `vfox search scala` lists 3.10.1, 2.13.18 and an `LTS` release.
3. `vfox install scala@3.10.1` prints `Verifying checksum` and installs. The release has a `.sha256` file on GitHub.
4. `vfox install scala@3.5.0` prints `Checksum is not provided` and installs. The release has none.
5. `vfox install scala@2.13.18` installs from GitHub.
6. `vfox use --global scala@3.10.1` in a shell where `vfox activate` has run, followed by `vfox env`, makes `scala -version` report 3.10.1. This is the path a user's shell takes. On Linux the shell is bash; on Windows it is PowerShell.
7. For each of the three versions, `vfox exec scala@<version> -- scalac -version` and a small program compiled with `scalac` and run with `scala` print their output.

**Archive and detect** adds the plugin, then:

1. `vfox install scala@2.10.4` installs from the scala-lang.org archive, which the plugin finds on the download page of 2.10.4. The group installs no other archive release.
2. A Scala 2.12.20 is put in a folder outside vfox, `/opt/scala-system` on Linux and `scala-system` under `ProgramFiles` on Windows. `vfox link --detect scala --yes` must find it, name it `2.12.20` and report the folder, and `vfox exec scala@2.12.20 -- scala -version` must then run it.

The Scala 2.12.20 of the second group is downloaded from GitHub without a digest in the suite: GitHub's API gives none for that release's assets, so the suite pins none. It is a fixture, not a vfox download. The vfox release itself is pinned to the digests that GitHub publishes for its assets, in `tests/e2e/common/common.go` and in the Test Plugin workflow.

## Running the Linux suite

You need Docker, network access to GitHub and scala-lang.org, and Go 1.27.1, the version the module names. An older Go downloads that toolchain on its own, unless `GOTOOLCHAIN=local` is set. From the repository root:

```bash
cd tests/e2e
go test -v -timeout 55m -run TestE2E ./linux
```

The dev container in `.devcontainer/` has Go, the Docker CLI and the tools of the workflows. Open it in an editor that supports dev containers, and it runs the same command through the host's Docker socket.

The test builds `vfox-scala-e2e:dev` from `tests/e2e/linux/Dockerfile` first; the image has vfox, verified against its release digest, and a Java runtime. The plugin is packed from the working tree on each run, so the suite tests what you have checked out, not what was published.

Containers are named `vfox-scala-e2e-<pid>-<n>`. A run that is killed may leave some behind, which you can remove with `docker rm --force $(docker ps -aq --filter name=vfox-scala-e2e-)`.

Only `linux/amd64` is covered. The image pins vfox for that architecture.

## Running the Windows suite

The Windows suite runs on a Windows host, with PowerShell 7 (`pwsh`) and a JDK on the `PATH`, since the Scala launchers need Java. It cannot run in Linux containers, and Windows containers are not used. From the repository root in PowerShell:

```powershell
cd tests/e2e
go test -v -timeout 55m -run TestE2E ./windows
```

The suite downloads the vfox 1.1.0 zip, checks its SHA-256, and runs `vfox.exe` from it. `VFOX_HOME` is in a folder whose path has a space, so the checks also cover paths like that. The `ProgramFiles` variable of the vfox process is pointed at a temporary folder, which is where the second group puts its Scala 2.12.20.

## Environment knobs

| Variable | Default | Meaning |
| --- | --- | --- |
| `E2E_RETRY_ATTEMPTS` | `3` | Attempts for each step that uses the network, such as search, install and the downloads of the suites. Attempts wait 10 seconds, then 20 |
| `-short` | off | The suites are skipped with `-short`; the packages' unit tests still run |

## Local checks

These are the commands of the Lint, Test Plugin and License workflows. Run them from the repository root unless a `cd` is given.

```bash
# Go: formatting, vet and unit tests (.github/workflows/lint.yml).
cd tests/e2e
test -z "$(gofmt -l .)"
go vet ./...
GOOS=windows go vet ./...
go test -short ./...
cd ../..

# Lua and workflows (.github/workflows/lint.yml).
stylua --check .
lua-language-server --check . --checklevel=Warning
go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.12
```

```bash
# Offline hook tests (.github/workflows/test.yml).
vfox plugin test .
```

```bash
# License headers (.github/workflows/license.yml).
license-eye header check
```

On a host without the tools, the license check runs as a container. CI does not use this image; it runs the `apache/skywalking-eyes@v0.9.0` action, which builds license-eye from source with `make install`. The image is the same version of the tool:

```bash
docker run --rm -v "$PWD:/work" -w /work apache/skywalking-eyes:0.9.0 header check
```

## What the suites do not cover

- Releases before 2.11 are checked by one install (2.10.4), not by running them.
- Windows containers, arm64 hosts and macOS. The plugin's download choices for macOS are the Linux ones.
- Scala installed from Homebrew, SDKMAN, asdf or mise, which the detection checks read but do not install.
