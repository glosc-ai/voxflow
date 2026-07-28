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
