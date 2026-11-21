# 开发

[中文](development.md) | [English](../development.md)

## 目录结构

```
.devcontainer/                用于 Linux 主机的开发容器，装有工作流固定的工具
metadata.lua                  插件名称、版本，以及 vfox add 打印的说明
hooks/available.lua           vfox search：scala-lang.org 的下载列表
hooks/pre_install.lua         vfox install：下载地址及其校验和
hooks/env_keys.lua            SCALA_HOME 与 PATH
hooks/detect.lua              vfox link --detect scala：机器上已有的 Scala
hooks/post_install.lua        无需处理
hooks/pre_use.lua             无需处理
lib/util.lua                  版本、下载地址、版本对应的归档、校验和
lib/detect_scala.lua          查找 Scala 主目录及其版本
tests/*_test.lua              离线钩子测试，由 vfox plugin test 运行
tests/e2e/                    用 Go 编写的端到端套件，见 e2e.md
Injection.lua                 vfox 注入对象的类型提示，从不被加载
README.md, README_CN.md, docs/
                              文档；docs/zh-CN/ 存放中文页面
opencode.jsonc                允许本仓库中的 OpenCode 代理会话无需询问即可执行 git push、gh pr create 与 gh pr comment
```

vfox 加载 `metadata.lua`，在命令需要时调用对应的钩子，并把 `PLUGIN` 和 `RUNTIME`（`osType`、`archType`、`version`）放入作用域。`osType` 与 `archType` 是 vfox 二进制文件的 Go `GOOS` 与 `GOARCH`，因此取值为 `windows`、`linux` 和 `darwin`。

## 每条命令运行什么

| 执行的命令 | 钩子 |
| --- | --- |
| `vfox search scala` | `Available` |
| `vfox install scala@3.10.1` | `PreInstall` 返回下载地址，若来自 GitHub 还返回校验和。vfox 负责下载并解压 |
| `vfox use scala@3.10.1` 和 `vfox exec` | `EnvKeys` 提供 `SCALA_HOME` 与 `PATH` |
| `vfox link --detect scala` | `Detect` 返回机器上已有的 Scala 安装（`lib/detect_scala.lua`） |

下面几条约定很费时间才摸清，列在这里：

- `PreInstall` 返回一个 table。`version` 为安装的名称，`url` 是 vfox 要下载的地址，校验和放在其算法名称之下，这里是 `sha256`。没有 `sha256` 键时，vfox 会发出警告并照常安装。
- `Available` 返回由 `{ version, note }` 组成的 table。长期支持版本的 note 为 `LTS`，版本名中不含备注：列表显示 `Scala 3.9.0 LTS`，插件返回的是版本 `3.9.0`，note 为 `LTS`。版本名为 `3.9.0 LTS` 的安装什么也装不上。
- `EnvKeys` 在 vfox 1.x 上从 `ctx.main.path` 读取安装目录，在较旧的约定中从 `ctx.path` 读取。两者都会读取。
- `Detect` 返回 `{ version, path, note }`，每个版本一条，因此同一个 Scala 即使能通过两条路径找到，也只提供一次。
- 无法读取下载列表时，`Available` 会抛出错误。它不会返回空列表，因为那看起来像是 Scala 没有任何发行版。
- 在 Windows 上，`RUNTIME.osType` 为 `windows`，因此 Windows 分支按这一拼写进行比较。

## 版本与下载

`lib/util.lua` 决定版本从哪里获取。表格与理由见 [versions.md](versions.md)。简而言之，Scala 3 以及 2.11 及以后的版本从 GitHub 获取，更早的发行版在 scala-lang.org 上，由各版本的下载页指明归档。`util.source_of` 是做出这一选择的唯一位置；其他函数采用它的结果。

校验和来自 GitHub 下载文件旁边的 `.sha256` 文件（如果存在）。`util.parse_sha256` 只接受 64 位的 SHA-256，其他内容一律忽略。

## 检测已安装的 Scala

`hooks/detect.lua` 把工作交给 `lib/detect_scala.lua`。它的根目录以及读取版本的顺序见 [detect.md](detect.md)。Windows 根目录使用 `dir /b` 列出内容，Unix 根目录使用 `ls -1`；只有在名称和 jar 都没有给出版本的主目录上，`io.popen` 才会运行 `scala -version`。

## 测试

离线测试在 `vfox plugin test` 下运行，vfox 1.0.13 及以后的版本都带有此命令。它会找到每个 `tests/**/*_test.lua`，并在各自独立的 VM 中运行每个文件，因此新增测试文件无需在任何地方登记：

```bash
vfox plugin test .
vfox plugin test . --file tests/util_test.lua
```

请在仓库根目录运行。Test Plugin 工作流会安装 vfox 1.1.0，版本固定在 `.github/workflows/test.yml` 中，因为 `vfox link --detect` 需要它。本地也请使用同一版本。

测试文件从 `vfox.test` 调用 `test.load()`，然后通过它返回的对象调用钩子，例如 `plugin:PreInstall({ version = "3.10.1" })`。`test.load` 接受平台（`os`、`arch`）、环境变量（`env`），以及一个回应每个 HTTP 请求的函数（`http`）。可以设置 `RUNTIME.osType` 来模拟其他平台。VM 禁用了 `io.popen` 与 `os.execute`，因此扫描器测试会像 `tests/detect_test.lua` 那样，把 `io.open` 和 `io.popen` 替换为模拟文件系统。

当新的检查需要来自网络的页面或文件时，把它在读取当天服务器返回的内容写进测试，并注明日期，如 `tests/available_test.lua` 与 `tests/util_test.lua` 所做的那样。

## 代码检查与许可证

请在仓库根目录运行。它们与工作流运行的命令相同。

```bash
# Lua
stylua --check .
lua-language-server --check . --checklevel=Warning

# Go，在 tests/e2e 中
(cd tests/e2e && test -z "$(gofmt -l .)" && go vet ./... && GOOS=windows go vet ./... && go test -short ./...)

# 工作流
go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.12

# 许可证文件头
license-eye header check
```

`license-eye` 即 Apache SkyWalking Eyes；Docker 形式见 [e2e.md](e2e.md#本地检查)。每个 Lua、Go、YAML、TOML、JSONC 与 Dockerfile 文件都以 `.licenserc.yaml` 中的 Apache 2.0 文件头开头。Markdown 与 JSON 文件不做检查。

要格式化 Lua，请使用工作流固定的版本运行 `stylua .`，因为不同版本的 stylua 输出会有变化。

## 发布

维护者在默认分支上，通过 **Actions → Plugin → Run workflow** 发布，输入不带 `v` 前缀的稳定插件版本号。共享工作流 [plugin-manifest-action](https://github.com/version-fox/plugin-manifest-action) 会更新 `metadata.lua`，创建版本提交与标签，并在本仓库中发布 ZIP 与 manifest。无需本地标签，也无需额外的发布令牌。拉取请求只运行检查。

推送版本标签时也会发布，前提是 `PLUGIN.version` 已与该标签一致。发布失败时，重新运行失败的任务即可继续。该工作流跟随共享的 `@v1` 发布工具，更新该工具本身不会发布本插件。

尚未发布的变更放在 [changes.md](changes.md) 中的 "未发布"（英文页为 "Unreleased"）之下。发布后，把它们移到对应版本号与日期之下，两种语言都要改。

## 编写文档

英文页位于 `docs/`，中文页位于 `docs/zh-CN/`，文件名相同；中文 README 为 `README_CN.md`。每个页面开头都链接到另一种语言的版本。新增页面要加入两份 README 的文档列表。
