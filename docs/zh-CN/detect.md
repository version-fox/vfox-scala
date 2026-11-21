# 查找机器上已有的 Scala

[中文](detect.md) | [English](../detect.md)

`vfox link --detect scala` 查找 vfox 没有安装的 Scala 安装，并链接找到的那些，这样你已有的 Scala 无需再次下载，即可通过 vfox 使用。它需要 vfox 1.1.0 或更高版本。

```bash
vfox link --detect scala        # 询问要链接哪些
vfox link --detect scala --yes  # 链接找到的全部
```

每一个被链接的安装都以它所标明的版本注册，之后的使用方式与已安装的版本相同：

```bash
vfox exec scala@2.12.20 -- scala -version
```

## 查找位置

检查每个根目录下的直接子文件夹，`SCALA_HOME` 则作为主目录本身检查。文件夹只有是 Scala 主目录（见下文）时才算作 Scala。

| 平台 | 根目录 | 涵盖范围 |
| --- | --- | --- |
| 所有平台 | `$SCALA_HOME` | 它所指定的文件夹，可以是主目录本身 |
| Linux 与 macOS | `~/.sdkman/candidates/scala` | SDKMAN |
| Linux 与 macOS | `~/.asdf/installs/scala`、`~/.local/share/mise/installs/scala` | asdf 与 mise |
| Linux 与 macOS | `/opt/homebrew/opt`、`/usr/local/opt` | 名称中含 `scala` 的 Homebrew keg |
| Linux 与 macOS | `/home/linuxbrew/.linuxbrew/opt`、`~/.linuxbrew/opt` | 名称中含 `scala` 的 Linuxbrew keg |
| Linux 与 macOS | `/opt`、`/usr/local`、`/usr/local/share`、`/usr/share`、`/usr/lib` | 名称中含 `scala` 的文件夹，例如 `/opt/scala-2.13.18` |
| Windows | `%USERPROFILE%\.asdf\installs\scala`、`%USERPROFILE%\.local\share\mise\installs\scala` | asdf 与 mise |
| Windows | `%USERPROFILE%\scoop\apps\scala` | Scoop，每个版本一个文件夹，与 `current` 并列 |
| Windows | `%ProgramFiles%` 与 `%ProgramFiles(x86)%` | 名称中含 `scala` 的文件夹 |

由 vfox 管理的文件夹（路径中含有 `.vfox` 文件夹）永远不会被报告。

## 什么是 Scala 主目录

Scala 主目录是一个含有 `bin/scala` 启动器的文件夹；在 Windows 上则是 `bin\scala.bat`。Homebrew keg 把发行版放在 `libexec` 中，因此插件也接受 `libexec/bin/scala`。

## 版本从哪里来

依次取第一个能给出版本的来源：

1. Scala 3 发行版的 `VERSION` 文件，其中有一行 `version:=3.5.0`。
2. `lib` 中的 jar 文件名：先看 `scala3-library_3-<version>.jar`，再看 `scala-library-<version>.jar`。Scala 3 也附带 Scala 2 的库，因此优先采用它自身的运行时。
3. 文件夹名称，前提是它是完整版本号：`scala-2.13.18`、`scala3-3.5.0` 或 `2.13.18`。只有主版本号和次版本号的名称（例如 Debian 的 `scala-2.12`）不够。
4. `scala -version` 的输出，这需要 Java 运行时。Scala 2 打印 `Scala code runner version 2.13.18`，Scala 3 打印 `Scala version (default): 3.5.0`。

四种来源都给不出版本的 Scala 不会被报告。Scala 2 发行版的 jar 不带版本号，因此由文件夹名称或启动器决定其版本。

## 每个版本一条记录

两个文件夹包含同一版本时（例如 SDKMAN 的 `3.5.0` 及其 `current` 链接），只保留一条记录：排序靠前的路径。每条记录的形式为 `{ version, path, note }`，其中 `note` 写明它被找到时所在的根目录，例如 `installed by SDKMAN` 或 `system Scala`。

## 如何测试

`tests/detect_*_test.lua` 中的离线测试在模拟文件系统上运行扫描器，覆盖 Linux 与 Windows 的根目录，包括 Linuxbrew keg 与 Scoop。macOS 的根目录（例如 `/opt/homebrew/opt`）与 Linux 走同一段代码路径，但没有自己的测试。端到端套件会在 vfox 之外手动安装一个 Scala，并检查 `vfox link --detect` 能否找到并链接它，参见 [e2e.md](e2e.md#套件检查的内容)。
