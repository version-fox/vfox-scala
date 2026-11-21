# E2E 端到端测试

[中文](e2e.md) | [English](../e2e.md)

端到端套件使用真实的 vfox 1.1.0 对本插件进行测试：插件会以 `vfox add --source` 接受的方式打包成 zip，并访问真实的下载服务器。`tests/*_test.lua` 中的离线测试在 **Test Plugin** 工作流中运行，不需要网络；参见 [development.md](development.md#测试)。

| 套件 | 运行位置 | 隔离方式 |
| --- | --- | --- |
| `tests/e2e/linux` | Docker 容器，由 `tests/e2e/linux/Dockerfile` 构建的镜像启动 | 每组检查使用一个新容器，结束后删除 |
| `tests/e2e/windows` | Windows 机器的主机，使用其发行版中的 `vfox.exe` | 每组检查使用一个新的 `VFOX_HOME` 与文件夹，位于临时文件夹之下 |

两个套件都是只使用标准库的 Go 程序，位于模块 `tests/e2e` 中。具体检查位于 `tests/e2e/common`，各平台包只决定 vfox 在哪里运行。CI 在 `ubuntu-latest` 上运行 Linux 套件，在 `windows-latest` 上运行 Windows 套件（即 **E2E** 工作流）。

## 套件检查的内容

每个套件有两组检查，两组共用同一套检查流程（`common.CheckInstallAndRun` 与 `common.CheckArchiveAndDetect`）。

**安装与运行**先从 zip 添加插件，然后：

1. `vfox info scala` 打印指向 README 的说明。
2. `vfox search scala` 列出 3.10.1、2.13.18 以及一个 `LTS` 发行版。
3. `vfox install scala@3.10.1` 打印 `Verifying checksum` 并完成安装。该发行版在 GitHub 上有 `.sha256` 文件。
4. `vfox install scala@3.5.0` 打印 `Checksum is not provided` 并完成安装。该发行版没有此文件。
5. `vfox install scala@2.13.18` 从 GitHub 安装。
6. 在已运行 `vfox activate` 的 shell 中执行 `vfox use --global scala@3.10.1`，再执行 `vfox env`，之后 `scala -version` 报告 3.10.1。这是用户 shell 所走的路径。在 Linux 上 shell 为 bash；在 Windows 上为 PowerShell。
7. 对三个版本中的每一个，`vfox exec scala@<version> -- scalac -version` 以及用 `scalac` 编译、用 `scala` 运行的一个小程序，都会打印其输出。

**归档与检测**先添加插件，然后：

1. `vfox install scala@2.10.4` 从 scala-lang.org 的归档安装，插件从 2.10.4 的下载页找到该归档。本组不安装其他归档发行版。
2. 一个 Scala 2.12.20 被放在 vfox 之外的文件夹中：Linux 上为 `/opt/scala-system`，Windows 上为 `ProgramFiles` 下的 `scala-system`。`vfox link --detect scala --yes` 必须找到它，将其命名为 `2.12.20` 并报告该文件夹；之后 `vfox exec scala@2.12.20 -- scala -version` 必须能够运行它。

第二组所用的 Scala 2.12.20 从 GitHub 下载，并按 `tests/e2e/common/common.go` 中固定的 SHA-256 校验。GitHub 的 API 没有为该发行版的资产提供摘要，因此固定的值是根据资产计算的，并与 scala-lang.org 提供的副本一致。下载内容一旦变化，套件即失败。它是测试夹具，不是 vfox 的下载。vfox 本身的发行版则按 GitHub 为其资产发布的摘要固定，见 `tests/e2e/common/common.go` 与 Test Plugin 工作流。

## 运行 Linux 套件

你需要 Docker、能访问 GitHub 与 scala-lang.org 的网络，以及模块声明的版本 Go 1.27.1。较旧的 Go 会自行下载该工具链，除非设置了 `GOTOOLCHAIN=local`。在仓库根目录执行：

```bash
cd tests/e2e
go test -v -timeout 55m -run TestE2E ./linux
```

`.devcontainer/` 中的开发容器包含 Go、Docker CLI 以及工作流所用的工具。用支持开发容器的编辑器打开它，即可通过主机的 Docker socket 运行同一条命令。

测试会先从 `tests/e2e/linux/Dockerfile` 构建 `vfox-scala-e2e:dev`；该镜像中有 vfox（已按其发行版摘要校验）以及 Java 运行时。每次运行都会从工作区打包插件，因此套件测试的是你检出的内容，而不是已发布的内容。

容器命名为 `vfox-scala-e2e-<pid>-<n>`。被终止的运行可能会留下部分容器，可用 `docker rm --force $(docker ps -aq --filter name=vfox-scala-e2e-)` 删除。

仅覆盖 `linux/amd64`。该镜像为此架构固定了 vfox。

## 运行 Windows 套件

Windows 套件在 Windows 主机上运行，需要 PowerShell 7（`pwsh`）以及 `PATH` 中的 JDK，因为 Scala 启动器需要 Java。它无法在 Linux 容器中运行，也不使用 Windows 容器。在仓库根目录的 PowerShell 中执行：

```powershell
cd tests/e2e
go test -v -timeout 55m -run TestE2E ./windows
```

套件下载 vfox 1.1.0 的 zip，校验其 SHA-256，并从中运行 `vfox.exe`。`VFOX_HOME` 位于路径含空格的文件夹中，因此检查也覆盖这类路径。第二组检查把 Scala 2.12.20 以 `scala-system` 的名称放入套件自己的 `Program Files` 文件夹，并让 vfox 的 `ProgramFiles` 指向该文件夹。Windows 还会设置 `ProgramW6432`，而在运行器上，只要该变量存在，子进程就会把真实的 `Program Files` 文件夹报告为 `ProgramFiles`，因此套件会把 `ProgramW6432` 从传给 vfox 的环境中去掉。这个变量是在运行器上通过对环境变量做二分查找发现的。

## 环境变量与参数

| 变量 | 默认值 | 含义 |
| --- | --- | --- |
| `E2E_RETRY_ATTEMPTS` | `3` | 每个使用网络的步骤（例如搜索、安装以及套件的下载）的尝试次数。尝试之间依次等待 10 秒、20 秒 |
| `-short` | off | 使用 `-short` 时跳过套件；各包的单元测试仍会运行 |

## 本地检查

以下命令分别来自 Lint、Test Plugin 与 License 工作流。除非命令中给出了 `cd`，否则请在仓库根目录运行。

```bash
# Go：格式、vet 与单元测试（.github/workflows/lint.yml）。
cd tests/e2e
test -z "$(gofmt -l .)"
go vet ./...
GOOS=windows go vet ./...
go test -short ./...
cd ../..

# Lua 与工作流（.github/workflows/lint.yml）。
stylua --check .
lua-language-server --check . --checklevel=Warning
go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.12
```

```bash
# 离线钩子测试（.github/workflows/test.yml）。
vfox plugin test .
```

```bash
# 许可证文件头（.github/workflows/license.yml）。
license-eye header check
```

在没有这些工具的主机上，可以用容器运行许可证检查，所用镜像的版本与 CI 相同（0.9.0）。注意：CI 并不使用该镜像，而是由 `apache/skywalking-eyes@v0.9.0` 这个 composite action 通过 `make install` 从源码安装 license-eye：

```bash
docker run --rm -v "$PWD:/work" -w /work apache/skywalking-eyes:0.9.0 header check
```

## 套件未覆盖的内容

- 2.11 之前的发行版只通过安装一个版本（2.10.4）来检查，并未运行。
- Windows 容器、arm64 主机以及 macOS。插件为 macOS 选择的下载来源与 Linux 相同。
- 通过 Homebrew、SDKMAN、asdf 或 mise 安装的 Scala。检测检查会读取它们，但不会安装它们。
