# 更新日志

[中文](changes.md) | [English](../changes.md)

每个发行版中的变更，按用户能察觉到的方式记录。GitHub 的 release 页面列出了各个拉取请求。本列表出现之前的发行版没有在此描述。

## 未发布

- `vfox install scala@3.0.0`，以及 `3.0.0-RC1` 等 Scala 3 候选版本，向 GitHub 请求了 Scala 3 并不发布的 `.tgz`，因此下载以 404 失败。现在改为 `.tar.gz`，在 Windows 上为 `.zip`。参见 [versions.md](versions.md#每个版本从哪里下载)。
- Scala 2.10.4 以及 2.11 至 2.13 的发行版向 `downloads.lightbend.com` 请求其文件，该站点对这些请求返回 403，因此无法安装。现在 Scala 2.11 及以后的版本从 GitHub 获取，2.10.4 以及 2.11 之前的发行版从各版本下载页所链接的归档获取：在 scala-lang.org 上，2.10.5 至 2.10.7 在 GitHub 上。参见 [versions.md](versions.md#每个版本从哪里下载)。
- `vfox install scala@2.5.0.final` 同样向 `downloads.lightbend.com` 请求其文件，而没有去请求拥有该文件的 scala-lang.org 归档。现在它从归档获取。
- `vfox search scala` 把 `3.9.0 LTS` 作为版本名提供，而这样的版本名无法安装任何内容。版本名应为 `3.9.0`，备注为 `LTS`。现在 `vfox install scala@"3.9.0 LTS"` 会被拒绝，因为带空格的名称不是版本。
- `vfox search scala` 每次运行都会打印 `nil`。下载列表读取失败时返回空列表，看起来像是 Scala 没有任何发行版。现在读取失败会报错，错误信息中给出 HTTP 状态码；没有列出任何版本的页面同样报错。
- 版本比较会丢弃版本号中所有非数字的部分，因此 `3.0.0-RC1` 与 `2.13.0-M5` 被当作正式版路由。现在按数字路由版本，并保留后缀。
- Scala 在 GitHub 下载文件旁发布的校验和，若存在则会被校验：`vfox install scala@3.10.1` 的输出中会出现 `Verifying checksum`。没有校验和时，vfox 与以前一样发出警告。
- `vfox link --detect scala` 查找机器上已有的 Scala 安装，并将其链接。它需要 vfox 1.1.0 或更高版本。参见 [detect.md](detect.md)。
- 英文与中文文档：版本、检测、开发、端到端套件以及本页。
- 每次变更都会进行的检查：Lua 使用 stylua 与 LuaLS，端到端套件的 gofmt、vet 与单元测试，工作流使用 actionlint，许可证文件头，`vfox plugin test` 下的离线钩子测试，以及 Linux（Docker）与 Windows 上的端到端套件。参见 [e2e.md](e2e.md)。
