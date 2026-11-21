# 版本

[中文](versions.md) | [English](../versions.md)

本页说明 `vfox search scala` 列出什么、每个版本从哪里下载，以及下载如何校验。

## 名称

Scala 版本按发布时的写法书写：`3.10.1`、`2.13.18`、`2.10.4`、`2.7.7.final`。候选版本与里程碑版本保留后缀，例如 `3.0.0-RC1` 或 `2.13.0-M5`。

`vfox search scala` 读取 [scala-lang.org](https://www.scala-lang.org/download/all.html) 的下载列表。长期支持（LTS）版本带有 `LTS` 标注：

```text
3.9.0    LTS
3.10.1
```

列表与页面中的顺序一致，最新的在前。

## 每个版本从哪里下载

下载来源取决于版本。Windows 一律取 zip；Linux 与 macOS 取 tar.gz 或 tgz。

| 版本 | 来源 | Linux 与 macOS | Windows |
| --- | --- | --- | --- |
| 3.0.0 及以后，包括候选版本 | GitHub，[scala/scala3](https://github.com/scala/scala3/releases) | `scala3-<version>.tar.gz` | `scala3-<version>.zip` |
| 2.11.0 及以后，包括候选版本和里程碑版本 | GitHub，[scala/scala](https://github.com/scala/scala/releases)，标签 `v<version>` | `scala-<version>.tgz` | `scala-<version>.zip` |
| 2.11.0 之前，直到 2.5.0 | 各版本下载页所链接的归档：在 [scala-lang.org](https://www.scala-lang.org/download/all.html) 上，2.10.5 至 2.10.7 在 [GitHub](https://github.com/scala/scala/releases) 上 | `.tar.gz` 或 `.tgz`，以页面所写为准 | `.zip` |

归档发行版的文件名没有统一格式（`scala-2.7.0-final.tar.gz`、`scala-2.7.7.final.tgz`、`scala-2.10.4.tgz`），因此插件会从所安装版本的下载页读取归档地址。若该页面没有列出当前平台可用的归档，安装会中止，并显示该页面的地址。

在本次发布之前，插件向 `downloads.lightbend.com` 请求 2.10.4 至 2.13.x 的版本，该站点对这些请求返回 403。2.11 及以后的版本现在改从 GitHub 获取。

## 校验和

插件提供了 SHA-256 摘要时，vfox 会用它校验下载文件。对于 GitHub 上的发行版，插件会查找下载文件旁边的 `.sha256` 文件；Scala 只为部分发行版发布此文件（3.10.1 有，3.5.0 没有）。没有该文件时，vfox 会打印：

```text
WARNING: Checksum is not provided, skip verify...
```

然后照常安装。无法读取的摘要按同样方式处理，因此缺少校验和文件不会中止安装。scala-lang.org 上的发行版，插件不提供校验和。

## 安装与使用

```bash
vfox install scala@3.10.1       # Scala 3，按其发布的校验和校验
vfox install scala@2.13.18      # Scala 2.13，从 GitHub 下载
vfox install scala@2.10.4       # Scala 2.10，从 scala-lang.org 下载
vfox use --global scala@3.10.1
vfox exec scala@3.10.1 -- scalac -version
```

`EnvKeys` 把 `SCALA_HOME` 设为已安装的 Scala，并把它的 `bin` 文件夹加入 `PATH`。

本仓库的检查只从归档安装一个发行版（2.10.4），并不运行它。参见 [e2e.md](e2e.md#套件检查的内容)。
