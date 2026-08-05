# Android Release 签名

Android Release 构建必须显式提供组织持有的签名材料。缺少任一输入时构建会失败，不会回退到 Debug 签名。

## 构建输入

通过环境变量或同名 Gradle 属性提供以下值：

- `VOXFLOW_ANDROID_KEYSTORE_PATH`：构建机上的 keystore 文件路径。
- `VOXFLOW_ANDROID_KEYSTORE_PASSWORD`：keystore 密码。
- `VOXFLOW_ANDROID_KEY_ALIAS`：签名密钥别名。
- `VOXFLOW_ANDROID_KEY_PASSWORD`：签名密钥密码。

签名文件和密码不得提交到仓库或写入日志。仓库现有忽略规则会排除常见的 `.jks`、`.keystore` 和 `key.properties` 文件，但发布者仍需在提交前检查暂存内容。

## 本地验证

运行以下命令验证失败即终止行为和一次性测试签名：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\verify_android_signing.ps1
```

脚本会先确认无签名输入的 Release 构建失败，再在系统临时目录生成一次性 keystore、构建 Release APK 并校验证书。脚本不会读取或修改组织正式签名材料。

传入 `-SplitPerAbi` 可验证发布工作流需要的三种 ABI 产物：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\verify_android_signing.ps1 -SplitPerAbi
```

## GitHub Actions 发布环境

跨平台发布工作流的 Android 构建作业绑定 `android-release` Environment。它有两个入口：

- 向 `main` 推送 `pubspec.yaml` 变更后，工作流比较推送前后的顶层 `version:`。只有完整版本真正变化时才执行质量门禁，并行构建 Android 与 Windows；两端全部通过后自动创建标签和 GitHub Release。
- 从 `main` 手工触发时执行相同的质量门禁和双平台构建，但只上传 Actions 构建制品，不创建标签或 GitHub Release。

发布标签保留 Flutter 完整版本，例如 `version: 1.0.0+2` 对应 `v1.0.0+2`。构建制品文件名会将该版本规范化为 `1.0.0-build.2`，避免只提升 Android build number 时复用旧标签或覆盖旧文件。

组织管理员需要在 `glosc-ai` 组织中配置以下 Actions Secret，并授权 `glosc-ai/voxflow` 仓库访问：

- `ANDROID_KEY_BASE64`：Release keystore 文件的 Base64 编码。
- `ANDROID_KEY_ALIAS`：keystore 中的 Release 密钥别名。
- `ANDROID_KEY_PASSWORD`：keystore 与 Release 密钥共用的密码。

仓库还必须配置一个非敏感 Actions Variable：

- `ANDROID_CERT_SHA256`：组织 Release 证书的固定 SHA-256 指纹，使用 64 个十六进制字符；允许输入冒号和空格，工作流会在比较前规范化。

首次在受保护环境中手工运行时，如果 `ANDROID_CERT_SHA256` 尚未配置，Android 作业会从 keystore 导出公开证书、把实际 SHA-256 写入运行摘要，然后在构建 APK 前失败。组织管理员应从独立保管的 keystore 再次核对该指纹，确认后写入仓库 Actions Variable 并重新运行。后续任何错误 keystore 都会因与固定指纹不一致而失败。

工作流会自动读取三个组织 Secret 并映射为 Gradle 的内部签名输入。Secret 不会写入日志或构建制品；公开证书指纹会写入运行摘要，作为发布验收证据。

`android-release` Environment 必须将部署来源限制为 `main`。建议同时设置必要审核人；如果保留 required reviewers，版本变化推送会在 Android 构建读取签名材料前等待批准，完全无人值守发布需要由组织管理员明确接受取消人工审批后的保护边界。

Android 构建作业始终生成三种 ABI APK 和只含文件名的 SHA-256 校验清单，逐个验证签名证书后上传为 Actions 构建制品。所有第三方 Action 都固定到完整提交 SHA，避免可变标签在读取签名材料的作业中被替换。Windows 作业独立生成并验证包含完整运行时的 x64 ZIP。只有版本变化推送会启动具有 `contents: write` 权限的发布作业，汇总四个二进制文件和统一 SHA-256 清单；其余作业保持 `contents: read`。

仓库的 Actions Workflow permissions 必须允许 `GITHUB_TOKEN` 写入仓库内容，标签规则也必须允许工作流创建 `v*` 标签。正式运行链接、Release 附件名称、统一校验清单和 Android 证书指纹构成发布验收证据。Windows ZIP 仍是未签名受限测试包，不包含 `.wsb` 沙盒配置。
