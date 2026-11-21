# vfox-scala

[中文](README_CN.md) | [English](README.md)

[vfox](https://vfox.dev/) 的 Scala 插件。

它安装 Scala 3 和 Scala 2 的各个发行版：2.11 及以后的版本从 GitHub 下载，更早的版本从 scala-lang.org 下载。对于 Scala 发布了 SHA-256 的下载，安装时会据此校验。它还能找到机器上已经装好的 Scala 并把它链接进来，这样无需再下载一份就能通过 vfox 使用。

## 安装

安装 [vfox](https://github.com/version-fox/vfox) 之后，添加插件、安装一个版本并选中它：

```bash
vfox add scala
vfox install scala@3.10.1
vfox use --global scala@3.10.1
scala -version
```

`scala -version` 显示当前选中的版本。要让 `scala` 出现在 `PATH` 中，需要把 vfox 接入你的 shell，参见 vfox 的[快速开始](https://vfox.dev/guides/quick-start.html)。Scala 运行在 Java 运行时之上，需要另外安装 Java。

`vfox search scala` 列出可用的发行版。

## 版本

版本号与 Scala 发布时的写法相同，例如 `3.10.1`、`2.13.18`、`2.10.4` 或 `2.7.7.final`。候选版本和里程碑版本保留后缀，例如 `3.0.0-RC1`。长期支持版本在 `vfox search` 中带有 `LTS` 标注。

```bash
vfox install scala@3.10.1       # 按其发布的 SHA-256 校验
vfox install scala@2.13.18      # 从 GitHub 下载
vfox install scala@2.10.4       # 从 scala-lang.org 归档下载
vfox exec scala@3.10.1 -- scalac -version
```

[docs/zh-CN/versions.md](docs/zh-CN/versions.md) 说明了每个版本从哪里下载，以及何时校验校验和。

## 机器上已有的 Scala

`vfox link --detect scala` 查找 vfox 没有安装的 Scala：`SCALA_HOME`、SDKMAN、asdf、mise、Homebrew、Scoop、系统目录和 Program Files。它会询问要链接哪些，加上 `--yes` 则全部链接。需要 vfox 1.1.0 或更高版本。

```bash
vfox link --detect scala --yes
vfox exec scala@2.12.20 -- scala -version
```

[docs/zh-CN/detect.md](docs/zh-CN/detect.md) 列出了它查找的位置，以及它如何读取每个版本。

## 文档

- [版本](docs/zh-CN/versions.md)：每个版本从哪里下载，以及校验和。
- [查找机器上已有的 Scala](docs/zh-CN/detect.md)
- [更新日志](docs/zh-CN/changes.md)
- [开发](docs/zh-CN/development.md)：目录结构、钩子、测试与检查。
- [E2E](docs/zh-CN/e2e.md)：Linux 与 Windows 上的端到端测试套件。

## 发布

维护者从 Plugin 工作流发布，见 [docs/zh-CN/development.md](docs/zh-CN/development.md#发布)。

## 许可证

Apache License 2.0，见 [LICENSE](LICENSE)。
