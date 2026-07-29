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

发布工作流绑定 `android-release` Environment。它有两个入口：

- 发布 GitHub Release 时自动构建 Release 标签对应的代码；标签必须指向 `main` 可达的提交。构建及验签成功后，三种 ABI APK 和 SHA-256 清单会附加到该 GitHub Release。
- 从 `main` 分支手工触发时执行同样的构建及验签，但只上传 Actions 构建制品，不会查找或修改 GitHub Release。

组织管理员需要在 `glosc-ai` 组织中配置以下 Actions Secret，并授权 `glosc-ai/voxflow` 仓库访问：

- `ANDROID_KEY_BASE64`：Release keystore 文件的 Base64 编码。
- `ANDROID_KEY_ALIAS`：keystore 中的 Release 密钥别名。
- `ANDROID_KEY_PASSWORD`：keystore 与 Release 密钥共用的密码。

工作流会自动读取这三个组织 Secret，并映射为 Gradle 的内部签名输入；它还会从 keystore 导出公开证书并推导预期 SHA-256 指纹，不需要额外配置证书指纹变量。Secret 不会写入日志或构建制品。

建议为 `android-release` Environment 设置必要审核人，并将部署来源限制为 `main` 和正式 Release 使用的标签模式（例如 `v*`）。如果 Environment 只允许 `main`，Release 标签触发的构建会在读取签名材料前被环境保护规则阻止。

构建作业始终生成三种 ABI APK 和只含文件名的 SHA-256 校验清单，逐个验证签名证书后上传为 Actions 构建制品。只有 GitHub Release 发布事件会启动具有 `contents: write` 权限的独立发布作业，并把这些文件附加到对应标签的 Release；手工运行的构建作业保持 `contents: read`。正式运行链接、Release 附件名称和证书指纹构成 #5 的发布验收证据。
