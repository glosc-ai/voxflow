# Android 发布签名由组织统一持有

首个上线版本及后续 Android 发布统一使用由 `glosc-ai` 组织持有的唯一 Release keystore。签名材料与密码通过 GitHub Actions 组织级 Secrets 注入发布流程，禁止提交到源代码仓库，也不使用 Debug 或临时签名；这是因为 Android 后续升级必须延续同一签名身份，集中保管可降低密钥遗失和多人各自签名造成的升级中断风险。
