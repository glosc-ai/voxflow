# 火山引擎 Seed-TTS 2.0 音色清单

> 调研日期：2026-08-05。官方音色页显示最近更新时间：2026.08.03 16:12:54。本文件只收录适用于 Seed-TTS 2.0 普通语音合成的主表与多语种表，不把 S2S 或 1.0 音色混入可选项。

## 结论

- [官方音色列表](https://docs.volcengine.com/docs/6561/1257544?lang=zh) 的“豆包语音合成模型2.0”主表有 **292** 行，其中 **93** 个是常规 `*_uranus_bigtts` 音色、**199** 个以 `ICL_` 开头；多语种表另有 **151** 个常规音色。当前客户端落地集选择主表的 93 个常规音色。
- [单向流式语音合成 HTTP 官方接口](https://docs.volcengine.com/docs/6561/2528925?lang=zh) 明确要求 `X-Api-Resource-Id: seed-tts-2.0`，并说明该资源支持“豆包语音合成模型2.0”音色；`speaker` 为必选参数。
- [官方模型列表](https://docs.volcengine.com/docs/6561/2499930?lang=zh) 将 TTS 2.0 与 ICL 2.0 分开：TTS 2.0 使用官方 2.0 音色，ICL 2.0 使用声音复刻接口训练的专属音色。因此客户端不能只凭“模型名以 `bytedance/` 开头”就套用本清单。
- 火山官方文档使用的资源标识是 `seed-tts-2.0`；项目/代理返回的 `bytedance/seed-tts-2.0` 是代理层模型名，不是火山文档中的原生资源标识。客户端应对这个已知代理模型做明确映射，而不是泛化到所有 ByteDance 模型。
- 官方接口示例直接使用 `zh_female_vv_uranus_bigtts`（Vivi 2.0），且它位于主表、没有流式限制备注，因此它是静态清单的最稳妥默认值。模型切换后若旧音色不在新清单中，应原子地重置到此默认值，绝不能继续发送 OpenAI 的 `alloy`。
- VoxFlow 已通过代理验证 `zh_female_cancan_uranus_bigtts`，因此当前产品为兼容既有用户保留它作为 ByteDance 默认音色；这是客户端兼容决策，不改变上述官方示例结论。

## 兼容边界

- **应使用本清单：** `bytedance/seed-tts-2.0`（代理模型）或上游资源明确为 `seed-tts-2.0` 的普通语音合成请求。
- **不应使用本清单：** `seed-icl-2.0`（声音复刻音色来自用户控制台）、端到端 S2S/O/SC 模型（官方页面另列 25 个 S2S 音色）、豆包语音合成 1.0（官方页面另列 149 行；其中存在重复 ID）。
- 官方接口文档还出现请求体 `model: seed-tts-2.0-standard`，但注明它在 `speaker` 为复刻音色时使用；不要把这个请求体字段与 `X-Api-Resource-Id: seed-tts-2.0` 或代理模型 ID 混为一谈。
- 多语种表页首写“有 16 个音色仅限单向流”，但当前表格实际只有 **15** 行带有该备注。下面逐行保留官方表格的实际备注；这是官方页自身的计数差异。普通非双向的 `/audio/speech` 代理调用不应因此删除这些音色，但若未来接入双向流，必须过滤所有带该备注的条目。
- 官方表格没有独立“性别”列。下面的 `female`/`male` 仅来自官方 Speaker ID 自身的命名标记，不应宣传为额外的官方人物属性。

## 当前客户端可直接落地清单（93 个）

这 93 项来自官方 Seed-TTS 2.0 **主表**，筛选规则是 `voice_type` 不以 `ICL_` 开头。它们是本票建议直接绑定 `bytedance/seed-tts-2.0` 的普通 `/audio/speech` 集合。

机器可读版本见同目录的 [volcengine-seed-tts-2.0-voices.json](./volcengine-seed-tts-2.0-voices.json)。JSON 中 `speakerId` 即请求的 `voice`/`speaker` 值；`officialExampleSpeakerId` 记录官方示例，`productDefaultSpeakerId` 记录 VoxFlow 的兼容默认值。

| 场景 | 展示名称 | Speaker ID | 语种/方言 | ID 性别标记 | 支持能力 | 特殊标签 |
|---|---|---|---|---|---|---|
| 通用场景 | Vivi 2.0 | `zh_female_vv_uranus_bigtts` | 语种：中文、日文、印尼、墨西哥西班牙语 / 方言：四川、陕西、东北 | female | 指令遵循 | — |
| 通用场景 | 小何 2.0 | `zh_female_xiaohe_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 云舟 2.0 | `zh_male_m191_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 通用场景 | 小天 2.0 | `zh_male_taocheng_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 通用场景 | 刘飞 2.0 | `zh_male_liufei_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 通用场景 | 魅力苏菲 2.0 | `zh_female_sophie_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 清新女声 2.0 | `zh_female_qingxinnvsheng_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 角色扮演 | 知性灿灿 2.0 | `zh_female_cancan_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 角色扮演 | 撒娇学妹 2.0 | `zh_female_sajiaoxuemei_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 甜美小源 2.0 | `zh_female_tianmeixiaoyuan_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 甜美桃子 2.0 | `zh_female_tianmeitaozi_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 爽快思思 2.0 | `zh_female_shuangkuaisisi_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 视频配音 | 佩奇猪 2.0 | `zh_female_peiqi_uranus_bigtts` | 中文 | female | 指令遵循 | 抖音同款,豆包同款,剪映同款 |
| 通用场景 | 邻家女孩 2.0 | `zh_female_linjianvhai_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 少年梓辛 2.0 | `zh_male_shaonianzixin_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 视频配音 | 猴哥 2.0 | `zh_male_sunwukong_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 教育场景 | Tina老师 2.0 | `zh_female_yingyujiaoxue_uranus_bigtts` | 中文、英式英语 | female | 指令遵循 | — |
| 客服场景 | 暖阳女声 2.0 | `zh_female_kefunvsheng_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 有声阅读 | 儿童绘本 2.0 | `zh_female_xiaoxue_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 视频配音 | 大壹 2.0 | `zh_male_dayi_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 视频配音 | 黑猫侦探社咪仔 2.0 | `zh_female_mizai_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 视频配音 | 鸡汤女 2.0 | `zh_female_jitangnv_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 魅力女友 2.0 | `zh_female_meilinvyou_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 视频配音 | 流畅女声 2.0 | `zh_female_liuchangnv_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 视频配音 | 儒雅逸辰 2.0 | `zh_male_ruyayichen_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 多语种 | Tim | `en_male_tim_uranus_bigtts` | 美式英语 | male | 指令遵循 | — |
| 多语种 | Dacey | `en_female_dacey_uranus_bigtts` | 美式英语 | female | 指令遵循 | — |
| 多语种 | Stokie | `en_female_stokie_uranus_bigtts` | 美式英语 | female | 指令遵循 | — |
| 通用场景 | 温柔妈妈 2.0 | `zh_female_wenroumama_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 解说小明 2.0 | `zh_male_jieshuoxiaoming_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 通用场景 | TVB女声 2.0 | `zh_female_tvbnv_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 译制片男 2.0 | `zh_male_yizhipiannan_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 通用场景 | 俏皮女声 2.0 | `zh_female_qiaopinv_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 角色扮演 | 直率英子 2.0 | `zh_female_zhishuaiyingzi_uranus_bigtts` | 中文 | female | 指令遵循 | 抖音同款,豆包同款,剪映同款 |
| 通用场景 | 邻家男孩 2.0 | `zh_male_linjiananhai_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 角色扮演 | 四郎 2.0 | `zh_male_silang_uranus_bigtts` | 中文 | male | 指令遵循 | 抖音同款,豆包同款,剪映同款 |
| 通用场景 | 儒雅青年 2.0 | `zh_male_ruyaqingnian_uranus_bigtts` | 中文 | male | 指令遵循 | 番茄小说同款,豆包同款,剪映同款 |
| 角色扮演 | 擎苍 2.0 | `zh_male_qingcang_uranus_bigtts` | 中文 | male | 指令遵循 | 番茄小说同款,豆包同款,抖音同款,剪映同款 |
| 角色扮演 | 熊二 2.0 | `zh_male_xionger_uranus_bigtts` | 中文 | male | 指令遵循 | 抖音同款,豆包同款,剪映同款 |
| 角色扮演 | 樱桃丸子 2.0 | `zh_female_yingtaowanzi_uranus_bigtts` | 中文 | female | 指令遵循 | 抖音同款,豆包同款,剪映同款 |
| 通用场景 | 温暖阿虎 2.0 | `zh_male_wennuanahu_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 通用场景 | 奶气萌娃 2.0 | `zh_male_naiqimengwa_uranus_bigtts` | 中文 | male | 指令遵循 | 剪映同款,豆包同款 |
| 通用场景 | 婆婆 2.0 | `zh_female_popo_uranus_bigtts` | 中文 | female | 指令遵循 | 抖音同款,豆包同款,剪映同款 |
| 通用场景 | 高冷御姐 2.0 | `zh_female_gaolengyujie_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 傲娇霸总 2.0 | `zh_male_aojiaobazong_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 角色扮演 | 懒音绵宝 2.0 | `zh_male_lanyinmianbao_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 通用场景 | 反卷青年 2.0 | `zh_male_fanjuanqingnian_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 通用场景 | 温柔淑女 2.0 | `zh_female_wenroushunv_uranus_bigtts` | 中文 | female | 指令遵循 | 番茄小说同款,豆包同款,剪映同款 |
| 角色扮演 | 古风少御 2.0 | `zh_female_gufengshaoyu_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 活力小哥 2.0 | `zh_male_huolixiaoge_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 有声阅读 | 霸气青叔 2.0 | `zh_male_baqiqingshu_uranus_bigtts` | 中文 | male | 指令遵循 | 番茄小说同款,豆包同款,剪映同款 |
| 有声阅读 | 悬疑解说 2.0 | `zh_male_xuanyijieshuo_uranus_bigtts` | 中文 | male | 指令遵循 | 抖音同款,豆包同款,剪映同款 |
| 通用场景 | 萌丫头 2.0 | `zh_female_mengyatou_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 贴心女声 2.0 | `zh_female_tiexinnvsheng_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 鸡汤妹妹 2.0 | `zh_female_jitangmei_uranus_bigtts` | 中文 | female | 指令遵循 | 抖音同款,豆包同款 |
| 通用场景 | 磁性解说男声 2.0 | `zh_male_cixingjieshuonan_uranus_bigtts` | 中文 | male | 指令遵循 | 抖音同款,剪映同款 |
| 通用场景 | 亮嗓萌仔 2.0 | `zh_male_liangsangmengzai_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 通用场景 | 开朗姐姐 2.0 | `zh_female_kailangjiejie_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 高冷沉稳 2.0 | `zh_male_gaolengchenwen_uranus_bigtts` | 中文 | male | 指令遵循 | 猫箱同款 |
| 通用场景 | 深夜播客 2.0 | `zh_male_shenyeboke_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 角色扮演 | 鲁班七号 2.0 | `zh_male_lubanqihao_uranus_bigtts` | 中文 | male | 指令遵循 | 抖音同款,豆包同款,剪映同款 |
| 通用场景 | 娇喘女声 2.0 | `zh_female_jiaochuannv_uranus_bigtts` | 中文 | female | 指令遵循 | 抖音同款,剪映同款 |
| 角色扮演 | 林潇 2.0 | `zh_female_linxiao_uranus_bigtts` | 中文 | female | 指令遵循 | 抖音同款,豆包同款,剪映同款 |
| 角色扮演 | 玲玲姐姐 2.0 | `zh_female_lingling_uranus_bigtts` | 中文 | female | 指令遵循 | 抖音同款,豆包同款,剪映同款 |
| 角色扮演 | 春日部姐姐 2.0 | `zh_female_chunribu_uranus_bigtts` | 中文 | female | 指令遵循 | 抖音同款,豆包同款,剪映同款 |
| 角色扮演 | 唐僧 2.0 | `zh_male_tangseng_uranus_bigtts` | 中文 | male | 指令遵循 | 抖音同款,豆包同款 |
| 角色扮演 | 庄周 2.0 | `zh_male_zhuangzhou_uranus_bigtts` | 中文 | male | 指令遵循 | 抖音同款,剪映同款 |
| 通用场景 | 开朗弟弟 2.0 | `zh_male_kailangdidi_uranus_bigtts` | 中文 | male | 指令遵循 | 抖音同款,剪映同款 |
| 角色扮演 | 猪八戒 2.0 | `zh_male_zhubajie_uranus_bigtts` | 中文 | male | 指令遵循 | 豆包同款,剪映同款 |
| 角色扮演 | 感冒电音姐姐 2.0 | `zh_female_ganmaodianyin_uranus_bigtts` | 中文 | female | 指令遵循 | 抖音同款,剪映同款 |
| 通用场景 | 谄媚女声 2.0 | `zh_female_chanmeinv_uranus_bigtts` | 中文 | female | 指令遵循 | 抖音同款,剪映同款 |
| 角色扮演 | 女雷神 2.0 | `zh_female_nvleishen_uranus_bigtts` | 中文 | female | 指令遵循 | 剪映同款,豆包同款 |
| 通用场景 | 亲切女声 2.0 | `zh_female_qinqienv_uranus_bigtts` | 中文 | female | 指令遵循 | 豆包同款 |
| 通用场景 | 快乐小东 2.0 | `zh_male_kuailexiaodong_uranus_bigtts` | 中文 | male | 指令遵循 | 豆包同款 |
| 通用场景 | 开朗学长 2.0 | `zh_male_kailangxuezhang_uranus_bigtts` | 中文 | male | 指令遵循 | 豆包同款 |
| 通用场景 | 悠悠君子 2.0 | `zh_male_youyoujunzi_uranus_bigtts` | 中文 | male | 指令遵循 | 豆包同款 |
| 通用场景 | 文静毛毛 2.0 | `zh_female_wenjingmaomao_uranus_bigtts` | 中文 | female | 指令遵循 | 豆包同款 |
| 通用场景 | 知性女声 2.0 | `zh_female_zhixingnv_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 清爽男大 2.0 | `zh_male_qingshuangnanda_uranus_bigtts` | 中文 | male | 指令遵循 | 豆包同款 |
| 通用场景 | 渊博小叔 2.0 | `zh_male_yuanboxiaoshu_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 通用场景 | 阳光青年 2.0 | `zh_male_yangguangqingnian_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 通用场景 | 清澈梓梓 2.0 | `zh_female_qingchezizi_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 甜美悦悦 2.0 | `zh_female_tianmeiyueyue_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 心灵鸡汤 2.0 | `zh_female_xinlingjitang_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 温柔小哥 2.0 | `zh_male_wenrouxiaoge_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 通用场景 | 柔美女友 2.0 | `zh_female_roumeinvyou_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 东方浩然 2.0 | `zh_male_dongfanghaoran_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 通用场景 | 温柔小雅 2.0 | `zh_female_wenrouxiaoya_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 天才童声 2.0 | `zh_male_tiancaitongsheng_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 角色扮演 | 武则天 2.0 | `zh_female_wuzetian_uranus_bigtts` | 中文 | female | 指令遵循 | 剪映同款 |
| 角色扮演 | 顾姐 2.0 | `zh_female_gujie_uranus_bigtts` | 中文 | female | 指令遵循 | 抖音同款,剪映同款 |
| 通用场景 | 广告解说 2.0 | `zh_male_guanggaojieshuo_uranus_bigtts` | 中文 | male | 指令遵循 | 剪映同款 |
| 有声阅读 | 少儿故事 2.0 | `zh_female_shaoergushi_uranus_bigtts` | 中文 | female | 指令遵循 | — |

> 多语种表另有 151 个非 ICL 音色，也属于官方 TTS 2.0，但它是独立表且包含推理模式与双向流限制。本票按 93 个主表常规音色落地时，应把这 151 项标为“后续扩展”，而不是标为“不兼容”。

## 官方全表附录

### 官方主表（292 行：93 常规 + 199 ICL）

来源：[“豆包语音合成模型2.0”音色列表](https://docs.volcengine.com/docs/6561/1257544?lang=zh#豆包语音合成模型2-0-音色列表)。

| 场景 | 展示名称 | Speaker ID | 语种/方言 | ID 性别标记 | 支持能力 | 特殊标签 |
|---|---|---|---|---|---|---|
| 通用场景 | Vivi 2.0 | `zh_female_vv_uranus_bigtts` | 语种：中文、日文、印尼、墨西哥西班牙语 / 方言：四川、陕西、东北 | female | 指令遵循 | — |
| 通用场景 | 小何 2.0 | `zh_female_xiaohe_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 云舟 2.0 | `zh_male_m191_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 通用场景 | 小天 2.0 | `zh_male_taocheng_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 通用场景 | 刘飞 2.0 | `zh_male_liufei_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 通用场景 | 魅力苏菲 2.0 | `zh_female_sophie_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 清新女声 2.0 | `zh_female_qingxinnvsheng_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 角色扮演 | 知性灿灿 2.0 | `zh_female_cancan_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 角色扮演 | 撒娇学妹 2.0 | `zh_female_sajiaoxuemei_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 甜美小源 2.0 | `zh_female_tianmeixiaoyuan_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 甜美桃子 2.0 | `zh_female_tianmeitaozi_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 爽快思思 2.0 | `zh_female_shuangkuaisisi_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 视频配音 | 佩奇猪 2.0 | `zh_female_peiqi_uranus_bigtts` | 中文 | female | 指令遵循 | 抖音同款,豆包同款,剪映同款 |
| 通用场景 | 邻家女孩 2.0 | `zh_female_linjianvhai_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 少年梓辛 2.0 | `zh_male_shaonianzixin_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 视频配音 | 猴哥 2.0 | `zh_male_sunwukong_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 教育场景 | Tina老师 2.0 | `zh_female_yingyujiaoxue_uranus_bigtts` | 中文、英式英语 | female | 指令遵循 | — |
| 客服场景 | 暖阳女声 2.0 | `zh_female_kefunvsheng_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 有声阅读 | 儿童绘本 2.0 | `zh_female_xiaoxue_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 视频配音 | 大壹 2.0 | `zh_male_dayi_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 视频配音 | 黑猫侦探社咪仔 2.0 | `zh_female_mizai_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 视频配音 | 鸡汤女 2.0 | `zh_female_jitangnv_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 魅力女友 2.0 | `zh_female_meilinvyou_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 视频配音 | 流畅女声 2.0 | `zh_female_liuchangnv_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 视频配音 | 儒雅逸辰 2.0 | `zh_male_ruyayichen_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 多语种 | Tim | `en_male_tim_uranus_bigtts` | 美式英语 | male | 指令遵循 | — |
| 多语种 | Dacey | `en_female_dacey_uranus_bigtts` | 美式英语 | female | 指令遵循 | — |
| 多语种 | Stokie | `en_female_stokie_uranus_bigtts` | 美式英语 | female | 指令遵循 | — |
| 通用场景 | 温柔妈妈 2.0 | `zh_female_wenroumama_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 解说小明 2.0 | `zh_male_jieshuoxiaoming_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 通用场景 | TVB女声 2.0 | `zh_female_tvbnv_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 译制片男 2.0 | `zh_male_yizhipiannan_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 通用场景 | 俏皮女声 2.0 | `zh_female_qiaopinv_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 角色扮演 | 直率英子 2.0 | `zh_female_zhishuaiyingzi_uranus_bigtts` | 中文 | female | 指令遵循 | 抖音同款,豆包同款,剪映同款 |
| 通用场景 | 邻家男孩 2.0 | `zh_male_linjiananhai_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 角色扮演 | 四郎 2.0 | `zh_male_silang_uranus_bigtts` | 中文 | male | 指令遵循 | 抖音同款,豆包同款,剪映同款 |
| 通用场景 | 儒雅青年 2.0 | `zh_male_ruyaqingnian_uranus_bigtts` | 中文 | male | 指令遵循 | 番茄小说同款,豆包同款,剪映同款 |
| 角色扮演 | 擎苍 2.0 | `zh_male_qingcang_uranus_bigtts` | 中文 | male | 指令遵循 | 番茄小说同款,豆包同款,抖音同款,剪映同款 |
| 角色扮演 | 熊二 2.0 | `zh_male_xionger_uranus_bigtts` | 中文 | male | 指令遵循 | 抖音同款,豆包同款,剪映同款 |
| 角色扮演 | 樱桃丸子 2.0 | `zh_female_yingtaowanzi_uranus_bigtts` | 中文 | female | 指令遵循 | 抖音同款,豆包同款,剪映同款 |
| 通用场景 | 温暖阿虎 2.0 | `zh_male_wennuanahu_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 通用场景 | 奶气萌娃 2.0 | `zh_male_naiqimengwa_uranus_bigtts` | 中文 | male | 指令遵循 | 剪映同款,豆包同款 |
| 通用场景 | 婆婆 2.0 | `zh_female_popo_uranus_bigtts` | 中文 | female | 指令遵循 | 抖音同款,豆包同款,剪映同款 |
| 通用场景 | 高冷御姐 2.0 | `zh_female_gaolengyujie_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 傲娇霸总 2.0 | `zh_male_aojiaobazong_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 角色扮演 | 懒音绵宝 2.0 | `zh_male_lanyinmianbao_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 通用场景 | 反卷青年 2.0 | `zh_male_fanjuanqingnian_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 通用场景 | 温柔淑女 2.0 | `zh_female_wenroushunv_uranus_bigtts` | 中文 | female | 指令遵循 | 番茄小说同款,豆包同款,剪映同款 |
| 角色扮演 | 古风少御 2.0 | `zh_female_gufengshaoyu_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 活力小哥 2.0 | `zh_male_huolixiaoge_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 有声阅读 | 霸气青叔 2.0 | `zh_male_baqiqingshu_uranus_bigtts` | 中文 | male | 指令遵循 | 番茄小说同款,豆包同款,剪映同款 |
| 有声阅读 | 悬疑解说 2.0 | `zh_male_xuanyijieshuo_uranus_bigtts` | 中文 | male | 指令遵循 | 抖音同款,豆包同款,剪映同款 |
| 通用场景 | 萌丫头 2.0 | `zh_female_mengyatou_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 贴心女声 2.0 | `zh_female_tiexinnvsheng_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 鸡汤妹妹 2.0 | `zh_female_jitangmei_uranus_bigtts` | 中文 | female | 指令遵循 | 抖音同款,豆包同款 |
| 通用场景 | 磁性解说男声 2.0 | `zh_male_cixingjieshuonan_uranus_bigtts` | 中文 | male | 指令遵循 | 抖音同款,剪映同款 |
| 通用场景 | 亮嗓萌仔 2.0 | `zh_male_liangsangmengzai_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 通用场景 | 开朗姐姐 2.0 | `zh_female_kailangjiejie_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 高冷沉稳 2.0 | `zh_male_gaolengchenwen_uranus_bigtts` | 中文 | male | 指令遵循 | 猫箱同款 |
| 通用场景 | 深夜播客 2.0 | `zh_male_shenyeboke_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 角色扮演 | 鲁班七号 2.0 | `zh_male_lubanqihao_uranus_bigtts` | 中文 | male | 指令遵循 | 抖音同款,豆包同款,剪映同款 |
| 通用场景 | 娇喘女声 2.0 | `zh_female_jiaochuannv_uranus_bigtts` | 中文 | female | 指令遵循 | 抖音同款,剪映同款 |
| 角色扮演 | 林潇 2.0 | `zh_female_linxiao_uranus_bigtts` | 中文 | female | 指令遵循 | 抖音同款,豆包同款,剪映同款 |
| 角色扮演 | 玲玲姐姐 2.0 | `zh_female_lingling_uranus_bigtts` | 中文 | female | 指令遵循 | 抖音同款,豆包同款,剪映同款 |
| 角色扮演 | 春日部姐姐 2.0 | `zh_female_chunribu_uranus_bigtts` | 中文 | female | 指令遵循 | 抖音同款,豆包同款,剪映同款 |
| 角色扮演 | 唐僧 2.0 | `zh_male_tangseng_uranus_bigtts` | 中文 | male | 指令遵循 | 抖音同款,豆包同款 |
| 角色扮演 | 庄周 2.0 | `zh_male_zhuangzhou_uranus_bigtts` | 中文 | male | 指令遵循 | 抖音同款,剪映同款 |
| 通用场景 | 开朗弟弟 2.0 | `zh_male_kailangdidi_uranus_bigtts` | 中文 | male | 指令遵循 | 抖音同款,剪映同款 |
| 角色扮演 | 猪八戒 2.0 | `zh_male_zhubajie_uranus_bigtts` | 中文 | male | 指令遵循 | 豆包同款,剪映同款 |
| 角色扮演 | 感冒电音姐姐 2.0 | `zh_female_ganmaodianyin_uranus_bigtts` | 中文 | female | 指令遵循 | 抖音同款,剪映同款 |
| 通用场景 | 谄媚女声 2.0 | `zh_female_chanmeinv_uranus_bigtts` | 中文 | female | 指令遵循 | 抖音同款,剪映同款 |
| 角色扮演 | 女雷神 2.0 | `zh_female_nvleishen_uranus_bigtts` | 中文 | female | 指令遵循 | 剪映同款,豆包同款 |
| 通用场景 | 亲切女声 2.0 | `zh_female_qinqienv_uranus_bigtts` | 中文 | female | 指令遵循 | 豆包同款 |
| 通用场景 | 快乐小东 2.0 | `zh_male_kuailexiaodong_uranus_bigtts` | 中文 | male | 指令遵循 | 豆包同款 |
| 通用场景 | 开朗学长 2.0 | `zh_male_kailangxuezhang_uranus_bigtts` | 中文 | male | 指令遵循 | 豆包同款 |
| 通用场景 | 悠悠君子 2.0 | `zh_male_youyoujunzi_uranus_bigtts` | 中文 | male | 指令遵循 | 豆包同款 |
| 通用场景 | 文静毛毛 2.0 | `zh_female_wenjingmaomao_uranus_bigtts` | 中文 | female | 指令遵循 | 豆包同款 |
| 通用场景 | 知性女声 2.0 | `zh_female_zhixingnv_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 清爽男大 2.0 | `zh_male_qingshuangnanda_uranus_bigtts` | 中文 | male | 指令遵循 | 豆包同款 |
| 通用场景 | 渊博小叔 2.0 | `zh_male_yuanboxiaoshu_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 通用场景 | 阳光青年 2.0 | `zh_male_yangguangqingnian_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 通用场景 | 清澈梓梓 2.0 | `zh_female_qingchezizi_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 甜美悦悦 2.0 | `zh_female_tianmeiyueyue_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 心灵鸡汤 2.0 | `zh_female_xinlingjitang_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 温柔小哥 2.0 | `zh_male_wenrouxiaoge_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 通用场景 | 柔美女友 2.0 | `zh_female_roumeinvyou_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 东方浩然 2.0 | `zh_male_dongfanghaoran_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 通用场景 | 温柔小雅 2.0 | `zh_female_wenrouxiaoya_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 通用场景 | 天才童声 2.0 | `zh_male_tiancaitongsheng_uranus_bigtts` | 中文 | male | 指令遵循 | — |
| 角色扮演 | 武则天 2.0 | `zh_female_wuzetian_uranus_bigtts` | 中文 | female | 指令遵循 | 剪映同款 |
| 角色扮演 | 顾姐 2.0 | `zh_female_gujie_uranus_bigtts` | 中文 | female | 指令遵循 | 抖音同款,剪映同款 |
| 通用场景 | 广告解说 2.0 | `zh_male_guanggaojieshuo_uranus_bigtts` | 中文 | male | 指令遵循 | 剪映同款 |
| 有声阅读 | 少儿故事 2.0 | `zh_female_shaoergushi_uranus_bigtts` | 中文 | female | 指令遵循 | — |
| 多语种 | Charlie 2.0 | `ICL_uranus_en_female_charlie_tob` | 美式英语 | female | — | — |
| 多语种 | Ethan 2.0 | `ICL_uranus_en_male_ethan_tob` | 澳洲英语 | male | — | — |
| 多语种 | Alastor 2.0 | `ICL_uranus_en_male_alastor_tob` | 英式英语 | male | — | — |
| 多语种 | Chucky 2.0 | `ICL_uranus_en_male_chucky_tob` | 美式英语 | male | — | — |
| 多语种 | Noah 2.0 | `ICL_uranus_en_male_noah_tob` | 美式英语 | male | — | — |
| 多语种 | Jigsaw 2.0 | `ICL_uranus_en_male_jigsaw_tob` | 美式英语 | male | — | — |
| 多语种 | Clown Man 2.0 | `ICL_uranus_en_male_clown_man_tob` | 美式英语 | male | — | — |
| 多语种 | Cartoon Chef 2.0 | `ICL_uranus_en_male_cartoon_chef_tob` | 美式英语 | male | — | — |
| 多语种 | Frosty Man 2.0 | `ICL_uranus_en_male_frosty_man_tob` | 美式英语 | male | — | 豆包同款 |
| 多语种 | The Grinch 2.0 | `ICL_uranus_en_male_the_grinch_tob` | 美式英语 | male | — | 豆包同款 |
| 多语种 | Kevin McCallister 2.0 | `ICL_uranus_en_male_kevin_mccallister_tob` | 美式英语 | male | — | 豆包同款 |
| 多语种 | Michael 2.0 | `ICL_uranus_en_male_michael_tob` | 美式英语 | male | — | 豆包同款 |
| 多语种 | Big Boogie 2.0 | `ICL_uranus_en_male_big_boogie_tob` | 美式英语 | male | — | 豆包同款 |
| 多语种 | Xavier 2.0 | `ICL_uranus_en_male_xavier_tob` | 美式英语 | male | — | — |
| 多语种 | Zayne 2.0 | `ICL_uranus_en_male_zayne_tob` | 美式英语 | male | — | — |
| 客服场景 | 客服婉君 2.0 | `ICL_uranus_zh_female_kefuwanjun_tob` | 中文 | female | — | — |
| 角色扮演,S2S-SC | 傲娇女友 2.0 | `ICL_uranus_zh_female_aojiaonvyou_tob` | 中文 | female | — | 豆包同款,猫箱同款 |
| 角色扮演 | 傲慢娇声 2.0 | `ICL_uranus_zh_female_aomanjiaosheng_tob` | 中文 | female | — | 猫箱同款 |
| 角色扮演 | 邪魅女王 2.0 | `ICL_uranus_zh_female_xiemeinvwang_tob` | 中文 | female | — | — |
| 角色扮演,S2S-SC | 病娇姐姐 2.0 | `ICL_uranus_zh_female_bingjiaojiejie_tob` | 中文 | female | — | 豆包同款,猫箱同款 |
| 角色扮演 | 病娇萌妹 2.0 | `ICL_uranus_zh_female_bingjiaomengmei_tob` | 中文 | female | — | 猫箱同款 |
| 角色扮演 | 病弱少女 2.0 | `ICL_uranus_zh_female_bingruoshaonv_tob` | 中文 | female | — | — |
| 角色扮演 | 成熟温柔 2.0 | `ICL_uranus_zh_female_chengshuwenrou_tob` | 中文 | female | — | 猫箱同款 |
| 角色扮演,S2S-SC | 成熟姐姐 2.0 | `ICL_uranus_zh_female_chengshujiejie_tob` | 中文 | female | — | 豆包同款,猫箱同款 |
| 角色扮演 | 纯真少女 2.0 | `ICL_uranus_zh_female_chunzhenshaonv_tob` | 中文 | female | — | 豆包同款 |
| 通用场景 | 纯澈女生 2.0 | `ICL_uranus_zh_female_chunchenvsheng_tob` | 中文 | female | — | — |
| 角色扮演 | 妩媚可人 2.0 | `ICL_uranus_zh_female_wumeikeren_tob` | 中文 | female | — | — |
| 客服场景 | 乖巧可儿 2.0 | `ICL_uranus_zh_female_guaiqiaokeer_tob` | 中文 | female | — | — |
| 视频配音 | 和蔼奶奶 2.0 | `ICL_uranus_zh_female_heainainai_tob` | 中文 | female | — | — |
| 角色扮演 | 活泼刁蛮 2.0 | `ICL_uranus_zh_female_huopodiaoman_tob` | 中文 | female | — | 猫箱同款 |
| 角色扮演 | 活泼女孩 2.0 | `ICL_uranus_zh_female_huoponvhai_tob` | 中文 | female | — | — |
| 角色扮演 | 娇憨女王 2.0 | `ICL_uranus_zh_female_jiaohannvwang_tob` | 中文 | female | — | 猫箱同款 |
| 角色扮演 | 娇弱萝莉 2.0 | `ICL_uranus_zh_female_jiaoruoluoli_tob` | 中文 | female | — | 猫箱同款 |
| 角色扮演 | 假小子 2.0 | `ICL_uranus_zh_female_jiaxiaozi_tob` | 中文 | female | — | 豆包同款,猫箱同款 |
| 角色扮演 | 精灵向导 2.0 | `ICL_uranus_zh_female_jinglingxiangdao_tob` | 中文 | female | — | 豆包同款 |
| 客服场景 | 开朗婷婷 2.0 | `ICL_uranus_zh_female_kailangtingting_tob` | 中文 | female | — | — |
| 客服场景 | 开心小鸿 2.0 | `ICL_uranus_zh_female_kaixinxiaohong_tob` | 中文 | female | — | — |
| 角色扮演,S2S-SC | 可爱女生 2.0 | `ICL_uranus_zh_female_keainvsheng_tob` | 中文 | female | — | 猫箱同款 |
| 客服场景 | 灵动欣欣 2.0 | `ICL_uranus_zh_female_lingdongxinxin_tob` | 中文 | female | — | — |
| 视频配音 | 邻居阿姨 2.0 | `ICL_uranus_zh_female_linjuayi_tob` | 中文 | female | — | — |
| 角色扮演 | 甜美娇俏 2.0 | `ICL_uranus_zh_female_tianmeijiaoqiao_tob` | 中文 | female | — | 猫箱同款 |
| 角色扮演 | 清冷高雅 2.0 | `ICL_uranus_zh_female_qinglenggaoya_tob` | 中文 | female | — | 猫箱同款 |
| 客服场景 | 理性圆子 2.0 | `ICL_uranus_zh_female_lixingyuanzi_tob` | 中文 | female | — | — |
| 角色扮演 | 性感魅惑 2.0 | `ICL_uranus_zh_female_xingganmeihuo_tob` | 中文 | female | — | — |
| 客服场景 | 暖心茜茜 2.0 | `ICL_uranus_zh_female_nuanxinqianqian_tob` | 中文 | female | — | — |
| 角色扮演,S2S-SC | 暖心学姐 2.0 | `ICL_uranus_zh_female_nuanxinxuejie_tob` | 中文 | female | — | 猫箱同款 |
| 客服场景 | 清甜莓莓 2.0 | `ICL_uranus_zh_female_qingtianmeimei_tob` | 中文 | female | — | — |
| 客服场景 | 清甜桃桃 2.0 | `ICL_uranus_zh_female_qingtiantaotao_tob` | 中文 | female | — | — |
| 客服场景 | 清晰小雪 2.0 | `ICL_uranus_zh_female_qingxixiaoxue_tob` | 中文 | female | — | — |
| 视频配音 | 倾心少女 2.0 | `ICL_uranus_zh_female_qingxinshaonv_tob` | 中文 | female | — | — |
| 角色扮演 | 柔骨魂师 2.0 | `ICL_uranus_zh_female_rouguhunshi_tob` | 中文 | female | — | 猫箱同款 |
| 客服场景 | 软萌糖糖 2.0 | `ICL_uranus_zh_female_ruanmengtangtang_tob` | 中文 | female | — | — |
| 客服场景 | 软萌团子 2.0 | `ICL_uranus_zh_female_ruanmengtuanzi_tob` | 中文 | female | — | — |
| 角色扮演 | 甜美活泼 2.0 | `ICL_uranus_zh_female_tianmeihuopo_tob` | 中文 | female | — | 猫箱同款 |
| 客服场景 | 甜美小橘 2.0 | `ICL_uranus_zh_female_tianmeixiaoju_tob` | 中文 | female | — | — |
| 客服场景 | 甜美小雨 2.0 | `ICL_uranus_zh_female_tianmeixiaoyu_tob` | 中文 | female | — | — |
| 角色扮演 | 调皮公主 2.0 | `ICL_uranus_zh_female_tiaopigongzhu_tob` | 中文 | female | — | 猫箱同款 |
| 角色扮演,S2S-SC | 贴心女友 2.0 | `ICL_uranus_zh_female_tiexinnvyou_tob` | 中文 | female | — | 豆包同款,猫箱同款 |
| 通用场景 | 温柔女神 2.0 | `ICL_uranus_zh_female_wenrounvshen_tob` | 中文 | female | — | 豆包同款 |
| 通用场景,S2S-SC | 温柔文雅 2.0 | `ICL_uranus_zh_female_wenrouwenya_tob` | 中文 | female | — | 猫箱同款 |
| 通用场景 | 知心姐姐 2.0 | `ICL_uranus_zh_female_zhixinjiejie_tob` | 中文 | female | — | — |
| 角色扮演,S2S-SC | 妩媚御姐 2.0 | `ICL_uranus_zh_female_wumeiyujie_tob` | 中文 | female | — | 豆包同款 |
| 通用场景 | 元气甜妹 2.0 | `ICL_uranus_zh_female_yuanqitianmei_tob` | 中文 | female | — | — |
| 角色扮演 | 邪魅御姐 2.0 | `ICL_uranus_zh_female_xiemeiyujie_tob` | 中文 | female | — | — |
| 角色扮演,S2S-SC | 性感御姐 2.0 | `ICL_uranus_zh_female_xingganyujie_tob` | 中文 | female | — | 豆包同款,猫箱同款 |
| 客服场景 | 秀丽倩倩 2.0 | `ICL_uranus_zh_female_xiuliqianqian_tob` | 中文 | female | — | — |
| 通用场景 | 贴心闺蜜 2.0 | `ICL_uranus_zh_female_tiexinguimi_tob` | 中文 | female | — | — |
| 通用场景 | 贴心妹妹 2.0 | `ICL_uranus_zh_female_tiexinmeimei_tob` | 中文 | female | — | — |
| 通用场景 | 温柔白月光 2.0 | `ICL_uranus_zh_female_wenroubaiyueguang_tob` | 中文 | female | — | — |
| 通用场景 | 初恋女友 2.0 | `ICL_uranus_zh_female_chuliannvyou_tob` | 中文 | female | — | — |
| 通用场景 | 知性温婉 2.0 | `ICL_uranus_zh_female_zhixingwenwan_tob` | 中文 | female | — | 猫箱同款 |
| 角色扮演,S2S-SC | 傲气凌人 2.0 | `ICL_uranus_zh_male_aoqilingren_tob` | 中文 | male | — | 猫箱同款 |
| 角色扮演 | 黯刃秦主 2.0 | `ICL_uranus_zh_male_anrenqinzhu_tob` | 中文 | male | — | 豆包同款 |
| 角色扮演,S2S-SC | 傲娇公子 2.0 | `ICL_uranus_zh_male_aojiaogongzi_tob` | 中文 | male | — | — |
| 角色扮演,S2S-SC | 傲娇精英 2.0 | `ICL_uranus_zh_male_aojiaojingying_tob` | 中文 | male | — | — |
| 角色扮演 | 傲慢青年 2.0 | `ICL_uranus_zh_male_aomanqingnian_tob` | 中文 | male | — | — |
| 角色扮演,S2S-SC | 傲慢少爷 2.0 | `ICL_uranus_zh_male_aomanshaoye_tob` | 中文 | male | — | 豆包同款,猫箱同款 |
| 角色扮演 | 枕边低语 2.0 | `ICL_uranus_zh_male_zhenbiandiyu_tob` | 中文 | male | — | 抖音同款 |
| 角色扮演,S2S-SC | 霸道少爷 2.0 | `ICL_uranus_zh_male_badaoshaoye_tob` | 中文 | male | — | — |
| 角色扮演 | 霸道总裁 2.0 | `ICL_uranus_zh_male_badaozongcai_tob` | 中文 | male | — | — |
| 角色扮演,S2S-SC | 病娇白莲 2.0 | `ICL_uranus_zh_male_bingjiaobailian_tob` | 中文 | male | — | 猫箱同款 |
| 角色扮演,S2S-SC | 病娇弟弟 2.0 | `ICL_uranus_zh_male_bingjiaodidi_tob` | 中文 | male | — | 豆包同款,猫箱同款 |
| 角色扮演 | 病娇哥哥 2.0 | `ICL_uranus_zh_male_bingjiaogege_tob` | 中文 | male | — | 豆包同款,猫箱同款 |
| 角色扮演 | 病娇男友 2.0 | `ICL_uranus_zh_male_bingjiaonanyou_tob` | 中文 | male | — | — |
| 角色扮演 | 病娇少年 2.0 | `ICL_uranus_zh_male_bingjiaoshaonian_tob` | 中文 | male | — | — |
| 角色扮演 | 病弱公子 2.0 | `ICL_uranus_zh_male_bingruogongzi_tob` | 中文 | male | — | 豆包同款 |
| 角色扮演 | 病弱少年 2.0 | `ICL_uranus_zh_male_bingruoshaonian_tob` | 中文 | male | — | — |
| 角色扮演 | 不羁青年 2.0 | `ICL_uranus_zh_male_bujiqingnian_tob` | 中文 | male | — | — |
| 视频配音 | 醇厚低音 2.0 | `ICL_uranus_zh_male_chunhoudiyin_tob` | 中文 | male | — | — |
| 视频配音 | 咆哮小哥 2.0 | `ICL_uranus_zh_male_paoxiaoxiaoge_tob` | 中文 | male | — | — |
| 通用场景 | 炀炀 2.0 | `ICL_uranus_zh_male_yangyang_tob` | 中文 | male | — | — |
| 角色扮演 | 孱弱少爷 2.0 | `ICL_uranus_zh_male_chanruoshaoye_tob` | 中文 | male | — | — |
| 角色扮演,S2S-SC | 成熟总裁 2.0 | `ICL_uranus_zh_male_chengshuzongcai_tob` | 中文 | male | — | — |
| 客服场景 | 沉稳明仔 2.0 | `ICL_uranus_zh_male_chenwenmingzai_tob` | 中文 | male | — | — |
| 角色扮演 | 清逸苏感 2.0 | `ICL_uranus_zh_male_qingyisugan_tob` | 中文 | male | — | 猫箱同款 |
| 角色扮演 | 纯真学弟 2.0 | `ICL_uranus_zh_male_chunzhenxuedi_tob` | 中文 | male | — | 豆包同款,猫箱同款 |
| 角色扮演,S2S-SC | 磁性男嗓 2.0 | `ICL_uranus_zh_male_cixingnansang_tob` | 中文 | male | — | — |
| 角色扮演 | 醋精男生 2.0 | `ICL_uranus_zh_male_cujingnansheng_tob` | 中文 | male | — | — |
| 角色扮演,S2S-SC | 醋精男友 2.0 | `ICL_uranus_zh_male_cujingnanyou_tob` | 中文 | male | — | — |
| 角色扮演 | 低音沉郁 2.0 | `ICL_uranus_zh_male_diyinchenyu_tob` | 中文 | male | — | — |
| 角色扮演,S2S-SC | 风发少年 2.0 | `ICL_uranus_zh_male_fengfashaonian_tob` | 中文 | male | — | — |
| 有声阅读 | 儒雅公子 2.0 | `ICL_uranus_zh_male_ruyagongzi_tob` | 中文 | male | — | — |
| 角色扮演,S2S-SC | 腹黑公子 2.0 | `ICL_uranus_zh_male_fuheigongzi_tob` | 中文 | male | — | 猫箱同款 |
| 角色扮演 | 干净少年 2.0 | `ICL_uranus_zh_male_ganjingshaonian_tob` | 中文 | male | — | — |
| 角色扮演 | 高冷总裁 2.0 | `ICL_uranus_zh_male_gaolengzongcai_tob` | 中文 | male | — | — |
| 角色扮演 | 孤傲公子 2.0 | `ICL_uranus_zh_male_guaogongzi_tob` | 中文 | male | — | 豆包同款 |
| 角色扮演 | 孤高公子 2.0 | `ICL_uranus_zh_male_gugaogongzi_tob` | 中文 | male | — | — |
| 角色扮演 | 诡异神秘 2.0 | `ICL_uranus_zh_male_guiyishenmi_tob` | 中文 | male | — | 猫箱同款 |
| 角色扮演 | 固执病娇 2.0 | `ICL_uranus_zh_male_guzhibingjiao_tob` | 中文 | male | — | 猫箱同款 |
| 角色扮演 | 憨厚敦实 2.0 | `ICL_uranus_zh_male_hanhoudunshi_tob` | 中文 | male | — | 猫箱同款 |
| 角色扮演 | 活力青年 2.0 | `ICL_uranus_zh_male_huoliqingnian_tob` | 中文 | male | — | — |
| 角色扮演 | 活泼男友 2.0 | `ICL_uranus_zh_male_huoponanyou_tob` | 中文 | male | — | — |
| 通用场景 | 活泼爽朗 2.0 | `ICL_uranus_zh_male_huoposhuanglang_tob` | 中文 | male | — | 猫箱同款 |
| 角色扮演 | 胡子叔叔 2.0 | `ICL_uranus_zh_male_huzishushu_tob` | 中文 | male | — | — |
| 角色扮演 | 机甲智能 2.0 | `ICL_uranus_zh_male_jijiazhineng_tob` | 中文 | male | — | — |
| 角色扮演 | 精英青年 2.0 | `ICL_uranus_zh_male_jingyingqingnian_tob` | 中文 | male | — | — |
| 角色扮演 | 俊逸公子 2.0 | `ICL_uranus_zh_male_junyigongzi_tob` | 中文 | male | — | — |
| 通用场景 | 开朗轻快 2.0 | `ICL_uranus_zh_male_kailangqingkuai_tob` | 中文 | male | — | 猫箱同款 |
| 角色扮演 | 开朗青年 2.0 | `ICL_uranus_zh_male_kailangqingnian_tob` | 中文 | male | — | — |
| 角色扮演 | 蓝银草魂师 2.0 | `ICL_uranus_zh_male_lanyincaohunshi_tob` | 中文 | male | — | 猫箱同款 |
| 角色扮演 | 冷傲总裁 2.0 | `ICL_uranus_zh_male_lengaozongcai_tob` | 中文 | male | — | — |
| 角色扮演 | 冷淡疏离 2.0 | `ICL_uranus_zh_male_lengdanshuli_tob` | 中文 | male | — | 猫箱同款 |
| 角色扮演 | 冷峻高智 2.0 | `ICL_uranus_zh_male_lengjungaozhi_tob` | 中文 | male | — | — |
| 角色扮演 | 冷峻上司 2.0 | `ICL_uranus_zh_male_lengjunshangsi_tob` | 中文 | male | — | 豆包同款,猫箱同款 |
| 通用场景 | 冷酷哥哥 2.0 | `ICL_uranus_zh_male_lengkugege_tob` | 中文 | male | — | 豆包同款 |
| 角色扮演 | 冷脸兄长 2.0 | `ICL_uranus_zh_male_lenglianxiongzhang_tob` | 中文 | male | — | — |
| 角色扮演 | 冷脸学霸 2.0 | `ICL_uranus_zh_male_lenglianxueba_tob` | 中文 | male | — | — |
| 角色扮演 | 冷漠男友 2.0 | `ICL_uranus_zh_male_lengmonanyou_tob` | 中文 | male | — | — |
| 角色扮演 | 冷漠兄长 2.0 | `ICL_uranus_zh_male_lengmoxiongzhang_tob` | 中文 | male | — | — |
| 角色扮演 | 凌云青年 2.0 | `ICL_uranus_zh_male_lingyunqingnian_tob` | 中文 | male | — | — |
| 角色扮演 | 清冷矜贵 2.0 | `ICL_uranus_zh_male_qinglengjingui_tob` | 中文 | male | — | 猫箱同款 |
| 角色扮演 | 绿茶小哥 2.0 | `ICL_uranus_zh_male_lvchaxiaoge_tob` | 中文 | male | — | 猫箱同款 |
| 角色扮演 | 懵懂青年 2.0 | `ICL_uranus_zh_male_mengdongqingnian_tob` | 中文 | male | — | — |
| 角色扮演 | 闷油瓶小哥 2.0 | `ICL_uranus_zh_male_menyoupingxiaoge_tob` | 中文 | male | — | 豆包同款 |
| 角色扮演 | 嚣张小哥 2.0 | `ICL_uranus_zh_male_xiaozhangxiaoge_tob` | 中文 | male | — | — |
| 角色扮演 | 粘人男友 2.0 | `ICL_uranus_zh_male_nianrennanyou_tob` | 中文 | male | — | — |
| 有声阅读 | 内敛才俊 2.0 | `ICL_uranus_zh_male_neiliancaijun_tob` | 中文 | male | — | — |
| 通用场景 | 暖心体贴 2.0 | `ICL_uranus_zh_male_nuanxintitie_tob` | 中文 | male | — | 猫箱同款 |
| 角色扮演 | 翩翩公子 2.0 | `ICL_uranus_zh_male_pianpiangongzi_tob` | 中文 | male | — | — |
| 角色扮演 | 沉稳优雅 2.0 | `ICL_uranus_zh_male_chenwenyouya_tob` | 中文 | male | — | 猫箱同款 |
| 角色扮演 | 青涩小生 2.0 | `ICL_uranus_zh_male_qingsexiaosheng_tob` | 中文 | male | — | 猫箱同款 |
| 角色扮演 | 青涩青年 2.0 | `ICL_uranus_zh_male_qingseqingnian_tob` | 中文 | male | — | — |
| 角色扮演 | 清爽少年 2.0 | `ICL_uranus_zh_male_qingshuangshaonian_tob` | 中文 | male | — | — |
| 客服场景 | 清新波波 2.0 | `ICL_uranus_zh_male_qingxinbobo_tob` | 中文 | male | — | — |
| 角色扮演 | 亲切青年 2.0 | `ICL_uranus_zh_male_qinqieqingnian_tob` | 中文 | male | — | — |
| 客服场景 | 亲切小卓 2.0 | `ICL_uranus_zh_male_qinqiexiaozhuo_tob` | 中文 | male | — | — |
| 角色扮演 | 清朗温润 2.0 | `ICL_uranus_zh_male_qinglangwenrun_tob` | 中文 | male | — | 猫箱同款 |
| 角色扮演 | 热血少年 2.0 | `ICL_uranus_zh_male_rexueshaonian_tob` | 中文 | male | — | — |
| 角色扮演 | 儒雅才俊 2.0 | `ICL_uranus_zh_male_ruyacaijun_tob` | 中文 | male | — | 猫箱同款 |
| 角色扮演 | 儒雅君子 2.0 | `ICL_uranus_zh_male_ruyajunzi_tob` | 中文 | male | — | — |
| 角色扮演 | 儒雅总裁 2.0 | `ICL_uranus_zh_male_ruyazongcai_tob` | 中文 | male | — | — |
| 角色扮演 | 撒娇男生 2.0 | `ICL_uranus_zh_male_sajiaonansheng_tob` | 中文 | male | — | — |
| 角色扮演 | 撒娇男友 2.0 | `ICL_uranus_zh_male_sajiaonanyou_tob` | 中文 | male | — | — |
| 角色扮演 | 撒娇粘人 2.0 | `ICL_uranus_zh_male_sajiaonianren_tob` | 中文 | male | — | 猫箱同款 |
| 角色扮演 | 洒脱青年 2.0 | `ICL_uranus_zh_male_satuoqingnian_tob` | 中文 | male | — | — |
| 角色扮演 | 少年将军 2.0 | `ICL_uranus_zh_male_shaonianjiangjun_tob` | 中文 | male | — | 豆包同款,猫箱同款 |
| 角色扮演 | 深沉总裁 2.0 | `ICL_uranus_zh_male_shenchenzongcai_tob` | 中文 | male | — | — |
| 通用场景 | 机灵小伙 2.0 | `ICL_uranus_zh_male_jilingxiaohuo_tob` | 中文 | male | — | — |
| 角色扮演 | 神秘法师 2.0 | `ICL_uranus_zh_male_shenmifashi_tob` | 中文 | male | — | 豆包同款,猫箱同款 |
| 通用场景 | 率真小伙 2.0 | `ICL_uranus_zh_male_shuaizhenxiaohuo_tob` | 中文 | male | — | 猫箱同款 |
| 客服场景 | 爽朗小阳 2.0 | `ICL_uranus_zh_male_shuanglangxiaoyang_tob` | 中文 | male | — | — |
| 角色扮演 | 低沉缱绻 2.0 | `ICL_uranus_zh_male_dichenqianquan_tob` | 中文 | male | — | 猫箱同款 |
| 角色扮演 | 斯文青年 2.0 | `ICL_uranus_zh_male_siwenqingnian_tob` | 中文 | male | — | — |
| 角色扮演 | 甜系男友 2.0 | `ICL_uranus_zh_male_tianxinanyou_tob` | 中文 | male | — | — |
| 角色扮演 | 贴心男友 2.0 | `ICL_uranus_zh_male_tiexinnanyou_tob` | 中文 | male | — | 豆包同款,猫箱同款 |
| 角色扮演 | 温柔男同桌 2.0 | `ICL_uranus_zh_male_wenrounantongzhuo_tob` | 中文 | male | — | 豆包同款,猫箱同款 |
| 角色扮演 | 温柔男友 2.0 | `ICL_uranus_zh_male_wenrounanyou_tob` | 中文 | male | — | — |
| 角色扮演 | 温柔学长 2.0 | `ICL_uranus_zh_male_wenrouxuezhang_tob` | 中文 | male | — | — |
| 角色扮演 | 温润学者 2.0 | `ICL_uranus_zh_male_wenrunxuezhe_tob` | 中文 | male | — | — |
| 角色扮演 | 温顺少年 2.0 | `ICL_uranus_zh_male_wenshunshaonian_tob` | 中文 | male | — | — |
| 角色扮演 | 寡言小哥 2.0 | `ICL_uranus_zh_male_guayanxiaoge_tob` | 中文 | male | — | 猫箱同款 |
| 角色扮演 | 小侯爷 2.0 | `ICL_uranus_zh_male_xiaohouye_tob` | 中文 | male | — | — |
| 角色扮演 | 奶气小生 2.0 | `ICL_uranus_zh_male_naiqixiaosheng_tob` | 中文 | male | — | 豆包同款 |
| 角色扮演 | 潇洒随性 2.0 | `ICL_uranus_zh_male_xiaosasuixing_tob` | 中文 | male | — | 猫箱同款 |
| 角色扮演 | 温柔内敛 2.0 | `ICL_uranus_zh_male_wenrouneilian_tob` | 中文 | male | — | 猫箱同款 |
| 角色扮演 | 学霸男同桌 2.0 | `ICL_uranus_zh_male_xuebanantongzhuo_tob` | 中文 | male | — | 豆包同款,猫箱同款 |
| 角色扮演 | 学霸同桌 2.0 | `ICL_uranus_zh_male_xuebatongzhuo_tob` | 中文 | male | — | — |
| 客服场景 | 阳光洋洋 2.0 | `ICL_uranus_zh_male_yangguangyangyang_tob` | 中文 | male | — | — |
| 有声阅读 | 温暖少年 2.0 | `ICL_uranus_zh_male_wennuanshaonian_tob` | 中文 | male | — | — |
| 角色扮演 | 意气少年 2.0 | `ICL_uranus_zh_male_yiqishaonian_tob` | 中文 | male | — | — |
| 角色扮演 | 油腻大叔 2.0 | `ICL_uranus_zh_male_younidashu_tob` | 中文 | male | — | — |
| 角色扮演 | 幽默大爷 2.0 | `ICL_uranus_zh_male_youmodaye_tob` | 中文 | male | — | 豆包同款,猫箱同款 |
| 角色扮演 | 幽默叔叔 2.0 | `ICL_uranus_zh_male_youmoshushu_tob` | 中文 | male | — | 豆包同款,猫箱同款 |
| 角色扮演 | 优柔帮主 2.0 | `ICL_uranus_zh_male_youroubangzhu_tob` | 中文 | male | — | 猫箱同款 |
| 角色扮演 | 优柔公子 2.0 | `ICL_uranus_zh_male_yourougongzi_tob` | 中文 | male | — | 豆包同款,猫箱同款 |
| 角色扮演 | 元气少年 2.0 | `ICL_uranus_zh_male_yuanqishaonian_tob` | 中文 | male | — | — |
| 角色扮演 | 仗剑君子 2.0 | `ICL_uranus_zh_male_zhangjianjunzi_tob` | 中文 | male | — | — |
| 角色扮演 | 仗剑侠客 2.0 | `ICL_uranus_zh_male_zhangjianxiake_tob` | 中文 | male | — | — |
| 角色扮演 | 正直青年 2.0 | `ICL_uranus_zh_male_zhengzhiqingnian_tob` | 中文 | male | — | 猫箱同款 |
| 角色扮演 | 直率青年 2.0 | `ICL_uranus_zh_male_zhishuaiqingnian_tob` | 中文 | male | — | — |
| 角色扮演 | 中二青年 2.0 | `ICL_uranus_zh_male_zhongerqingnian_tob` | 中文 | male | — | — |
| 角色扮演 | 自负青年 2.0 | `ICL_uranus_zh_male_zifuqingnian_tob` | 中文 | male | — | — |
| 角色扮演 | 自信青年 2.0 | `ICL_uranus_zh_male_zixinqingnian_tob` | 中文 | male | — | — |
| 角色扮演 | 天才同桌 2.0 | `ICL_uranus_zh_male_tiancaitongzhuo_tob` | 中文 | male | — | — |
| 客服场景 | 清新沐沐 2.0 | `ICL_uranus_zh_male_qingxinmumu_tob` | 中文 | male | — | — |
| 客服场景 | 温婉珊珊 2.0 | `ICL_uranus_zh_female_wenwanshanshan_tob` | 中文 | female | — | — |
| 客服场景 | 热情艾娜 2.0 | `ICL_uranus_zh_female_reqingaina_tob` | 中文 | female | — | — |
| 角色扮演 | 爽朗少年 2.0 | `ICL_uranus_zh_male_shuanglangshaonian_tob` | 中文 | male | — | — |
| 客服场景 | 轻盈朵朵 2.0 | `ICL_uranus_zh_female_qingyingduoduo_tob` | 中文 | female | — | — |

### 官方多语种表（151 个，当前阶段暂缓）

来源：[“豆包语音合成模型2.0”多语种音色列表](https://docs.volcengine.com/docs/6561/1257544?lang=zh#豆包语音合成模型2-0-多语种音色列表)。

| 场景 | 展示名称 | Speaker ID | 语种/方言 | ID 性别标记 | 推荐推理模式 | 支持能力 | 限制备注 |
|---|---|---|---|---|---|---|---|
| 通用场景, 视频配音,多语种,阿拉伯语 | Dina | `ar_female_dina_uranus_bigtts` | 阿拉伯语 | female | QA | 情感变化、指令遵循 | — |
| 趣味口音,多语种,阿拉伯语 | Fatma | `ar_female_fatma_uranus_bigtts` | 阿拉伯语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景,有声阅读,多语种,阿拉伯语 | Youssef | `ar_male_youssef_uranus_bigtts` | 阿拉伯语 | male | QA | 情感变化、指令遵循 | — |
| 教学场景, 客服场景,多语种,德语 | Stella | `de_female_bv081_uranus_bigtts` | 德语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 教学场景,多语种,德语 | Sven | `de_male_sven_uranus_bigtts` | 德语 | male | Context | 情感变化、上下文遵循 | 仅限单向流使用，不支持双向流，双向流调用会直接报错； |
| 通用场景,有声阅读,美式英语,多语种 | Rowan | `en_male_adam-imitation_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 通用场景, 教学场景,美式英语,多语种 | Alberto | `en_male_alberto_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,美式英语,多语种 | Alex | `en_male_alex_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 视频配音,美式英语,多语种 | Allison | `en_female_allison_uranus_bigtts` | 美式英语 | female | QA | 情感变化、指令遵循 | — |
| 教学场景, 视频配音,美式英语,多语种 | Charlotte | `en_female_authoritative-british_uranus_bigtts` | 美式英语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景,有声阅读,美式英语,多语种 | Margaret | `en_female_authoritative-informative_uranus_bigtts` | 美式英语 | female | QA | 情感变化、指令遵循 | — |
| 趣味口音,美式英语,多语种 | Jones | `en_male_bill-jones_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,美式英语,多语种 | Bill | `en_male_bill_jones_corey_uranus_bigtts` | 美式英语 | male | Context | 情感变化、上下文遵循 | 仅限单向流使用，不支持双向流，双向流调用会直接报错； |
| 通用场景, 视频配音,美式英语,多语种 | Brad_Pitt | `en_male_brad_pitt_p1_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,美式英语,多语种 | Brittney | `en_female_brittney_uranus_bigtts` | 美式英语 | female | QA | 情感变化、指令遵循 | — |
| 有声阅读, 客服场景,美式英语,多语种 | Zoe | `en_female_brittney_pimintel_uranus_bigtts` | 美式英语 | female | Context | 情感变化、上下文遵循 | 仅限单向流使用，不支持双向流，双向流调用会直接报错； |
| 通用场景, 视频配音,美式英语,多语种 | Adrian | `en_male_bruce_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 趣味口音,美式英语,多语种 | Leo | `en_male_chandler_p1_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 通用场景, 教学场景,美式英语,多语种 | Bob | `en_male_cowboy-bob_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 趣味口音, 角色扮演,美式英语,多语种 | John | `en_male_cowboy_john_b_uranus_bigtts` | 美式英语 | male | Context | 情感变化、上下文遵循 | 仅限单向流使用，不支持双向流，双向流调用会直接报错； |
| 通用场景,有声阅读,美式英语,多语种 | David | `en_male_david_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 趣味口音, 角色扮演,美式英语,多语种 | Orion | `en_male_deep-voice_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 有声阅读,美式英语,多语种 | Julian | `en_male_diyuwenrounan_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 视频配音,美式英语,多语种 | Harrison | `en_male_evil-guy-oxley_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 趣味口音,美式英语,多语种 | Jasper | `en_male_excited-male-voice_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 通用场景,有声阅读, 视频配音,美式英语,多语种 | Alfred | `en_male_father-christmas_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 教学场景, 视频配音,美式英语,多语种 | Holly | `en_female_female_tutor_ms-jenny_uranus_bigtts` | 美式英语 | female | Context | 情感变化、上下文遵循 | — |
| 通用场景, 教学场景,美式英语,多语种 | Felix | `en_male_fernando-martinez_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 有声阅读, 角色扮演,美式英语,多语种 | Godfather | `en_male_godfather_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 角色扮演,美式英语,多语种 | Gollum | `en_male_gollum_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,美式英语,多语种 | Beau | `en_male_hades_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 教学场景, 视频配音,美式英语,多语种 | Hayley | `en_female_hayley_uranus_bigtts` | 美式英语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 教学场景, 视频配音,美式英语,多语种 | Jamie | `en_male_jamie_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 视频配音,美式英语,多语种 | Jane | `en_female_jane_uranus_bigtts` | 美式英语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 客服场景,美式英语,多语种 | Jenny | `en_female_jenny_uranus_bigtts` | 美式英语 | female | QA | 情感变化、指令遵循 | — |
| 趣味口音, 角色扮演,美式英语,多语种 | Blaze | `en_male_jidongchuanjiaoshi_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,美式英语,多语种 | Jimmy | `en_male_jimmy_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 通用场景,有声阅读, 视频配音,美式英语,多语种 | Joanne | `en_female_joanne_uranus_bigtts` | 美式英语 | female | QA | 情感变化、指令遵循 | — |
| 趣味口音, 视频配音,美式英语,多语种 | Joker | `en_male_joker_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 视频配音,美式英语,多语种 | Josh | `en_male_josh_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 教学场景, 视频配音,美式英语,多语种 | Josiah | `en_male_josh_coery_uranus_bigtts` | 美式英语 | male | Context | 情感变化、上下文遵循 | 仅限单向流使用，不支持双向流，双向流调用会直接报错； |
| 教学场景, 视频配音,美式英语,多语种 | Kevin | `en_male_kevin_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 有声阅读,美式英语,多语种 | Knightley | `en_male_knightley_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 角色扮演,美式英语,多语种 | Lynn | `en_female_lana_del_rey_kelley_d_p1_uranus_bigtts` | 美式英语 | female | QA | 情感变化、指令遵循 | — |
| 客服场景,美式英语,多语种 | Ivy | `en_female_lana_del_rey_parky_s_p1_uranus_bigtts` | 美式英语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景,有声阅读,美式英语,多语种 | Marcus | `en_male_marcus_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 教学场景, 客服场景,美式英语,多语种 | Mel | `en_female_mel_uranus_bigtts` | 美式英语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 教学场景,美式英语,多语种 | Hank | `en_male_michael_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 趣味口音, 角色扮演,美式英语,多语种 | Chip | `en_male_michael-mouse_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 通用场景, 教学场景,美式英语,多语种 | Michael_Kevin | `en_male_michael_kevin_uranus_bigtts` | 美式英语 | male | Context | 情感变化、上下文遵循 | 仅限单向流使用，不支持双向流，双向流调用会直接报错； |
| 趣味口音, 视频配音,美式英语,多语种 | Rory | `en_male_motivational-coach_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 教学场景,美式英语,多语种 | Myra | `en_female_myra_uranus_bigtts` | 美式英语 | female | QA | 情感变化、指令遵循 | — |
| 教学场景, 客服场景,美式英语,多语种 | Sunny | `en_female_myra_cmb_uranus_bigtts` | 美式英语 | female | Context | 情感变化、上下文遵循 | 仅限单向流使用，不支持双向流，双向流调用会直接报错； |
| 通用场景, 视频配音,美式英语,多语种 | Blair | `en_female_nadia_uranus_bigtts` | 美式英语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,美式英语,多语种 | Natasha | `en_female_natasha_uranus_bigtts` | 美式英语 | female | QA | 情感变化、指令遵循 | 仅限单向流使用，不支持双向流，双向流调用会直接报错； |
| 有声阅读,视频配音,美式英语,多语种 | Elaine | `en_female_pleasant-female_uranus_bigtts` | 美式英语 | female | QA | 情感变化、指令遵循 | — |
| 趣味口音,美式英语,多语种 | Rachel | `en_female_rachel_p1_uranus_bigtts` | 美式英语 | female | QA | 情感变化、指令遵循 | — |
| 有声阅读,美式英语,多语种 | Ronald | `en_male_ronald_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 通用场景, 教学场景,美式英语,多语种 | Russell | `en_male_russell_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 客服场景,美式英语,多语种 | Scarlet | `en_female_scarlet_p1_uranus_bigtts` | 美式英语 | female | QA | 情感变化、指令遵循 | — |
| 趣味口音,美式英语,多语种 | Sharron | `en_female_sharron_uranus_bigtts` | 美式英语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,美式英语,多语种 | Simba | `en_male_simba_p1_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 通用场景,美式英语,多语种 | Skye | `en_female_skye_uranus_bigtts` | 美式英语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景,有声阅读,美式英语,多语种 | Tom | `en_male_tom_hiddleston_p1_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,美式英语,多语种 | Valentino | `en_male_valentino_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 视频配音,美式英语,多语种 | Clark | `en_male_valentino_corey_uranus_bigtts` | 美式英语 | male | Context | 情感变化、上下文遵循 | 仅限单向流使用，不支持双向流，双向流调用会直接报错； |
| 客服场景,美式英语,多语种 | Megan | `en_female_wenrouzhishijieshuonv_uranus_bigtts` | 美式英语 | female | QA | 情感变化、指令遵循 | — |
| 角色扮演,美式英语,多语种 | Kayla | `en_female_xinwenjieshuonv_uranus_bigtts` | 美式英语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,美式英语,多语种 | Dylan | `en_male_yangguangjieshuonan_uranus_bigtts` | 美式英语 | male | QA | 情感变化、指令遵循 | — |
| 教学场景, 客服场景,美式英语,多语种 | Zendaya | `en_female_zendaya_p1_uranus_bigtts` | 美式英语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 客服场景,多语种,西班牙语 | Gracie | `es_female_bv084_uranus_bigtts` | 西班牙语 | female | QA | 情感变化、指令遵循 | — |
| 有声阅读,视频配音,多语种,西班牙语 | Dani | `es_male_dani_uranus_bigtts` | 西班牙语 | male | QA | 情感变化、指令遵循 | — |
| 有声阅读,多语种,西班牙语 | Guillem | `es_male_guillem_uranus_bigtts` | 西班牙语 | male | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,多语种,西班牙语 | Marisol | `es_female_ht_mx_f6_uranus_bigtts` | 西班牙语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,多语种,法语 | Simone | `fr_female_fr_bv078_uranus_bigtts` | 法语 | female | QA | 情感变化、指令遵循 | — |
| 教学场景, 客服场景,多语种,法语 | Camille | `fr_female_fr_f47_uranus_bigtts` | 法语 | female | QA | 情感变化、指令遵循 | — |
| 有声阅读,视频配音,多语种,法语 | Maurice | `fr_male_fr_m29_uranus_bigtts` | 法语 | male | QA | 情感变化、指令遵循 | — |
| 通用场景, 客服场景,多语种,法语 | Usseau | `fr_male_usseau_uranus_bigtts` | 法语 | male | Context | 情感变化、上下文遵循 | 仅限单向流使用，不支持双向流，双向流调用会直接报错； |
| 通用场景, 视频配音,多语种,印尼语 | Rocco | `id_male_bv160_uranus_bigtts` | 印尼语 | male | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,多语种,印尼语 | Jude | `id_male_bv160dialogue_uranus_bigtts` | 印尼语 | male | QA | 情感变化、指令遵循 | — |
| 有声阅读,视频配音,多语种,印尼语 | Hugo | `id_male_bv160narration_uranus_bigtts` | 印尼语 | male | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,多语种,印尼语 | Clara | `id_female_bv161_uranus_bigtts` | 印尼语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,多语种,印尼语 | Sylvia | `id_female_bv161dialogue_uranus_bigtts` | 印尼语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,多语种,印尼语 | Celeste | `id_female_bv161narration_uranus_bigtts` | 印尼语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,多语种,印尼语 | Crew | `id_female_bv164_uranus_bigtts` | 印尼语 | female | QA | 情感变化、指令遵循 | — |
| 视频配音,多语种,印尼语 | Elian | `id_male_bv164dialogue_uranus_bigtts` | 印尼语 | male | QA | 情感变化、指令遵循 | — |
| 有声阅读,视频配音,多语种,印尼语 | Ronan | `id_male_bv164narration_uranus_bigtts` | 印尼语 | male | QA | 情感变化、指令遵循 | — |
| 视频配音,多语种,印尼语 | Chloe | `id_female_f20_uranus_bigtts` | 印尼语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景,多语种,印尼语 | Han | `id_male_han_uranus_bigtts` | 印尼语 | male | Context | 情感变化、指令遵循、上下文遵循 | — |
| 通用场景, 教学场景,多语种,印尼语 | Kyle | `id_male_m08_uranus_bigtts` | 印尼语 | male | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,多语种,印尼语 | Phulia | `id_female_phulia_uranus_bigtts` | 印尼语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 教学场景,多语种,日语 | Bonnie | `ja_female_bv024_uranus_bigtts` | 日语 | female | QA | 情感变化、指令遵循 | — |
| 视频配音, 角色扮演,多语种,日语 | Poppy | `ja_female_bv520_uranus_bigtts` | 日语 | female | QA | 情感变化、指令遵循 | — |
| 趣味口音, 角色扮演,多语种,日语 | Aoi | `ja_female_bv521_uranus_bigtts` | 日语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 教学场景, 客服场景,多语种,日语 | Hana | `ja_female_bv522_uranus_bigtts` | 日语 | female | QA | 情感变化、指令遵循 | — |
| 趣味口音, 角色扮演,多语种,日语 | Lily | `ja_female_bv523_uranus_bigtts` | 日语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,多语种,日语 | Ken | `ja_male_bv524_uranus_bigtts` | 日语 | male | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,多语种,日语 | Minimi | `ja_female_minimi_uranus_bigtts` | 日语 | female | Context | 情感变化、上下文遵循 | 仅限单向流使用，不支持双向流，双向流调用会直接报错； |
| 视频配音, 角色扮演,多语种,日语 | Shirou | `ja_female_shirou_uranus_bigtts` | 日语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,多语种,韩语 | Jay | `ko_male_bv545_uranus_bigtts` | 韩语 | male | QA | 情感变化、指令遵循 | — |
| 视频配音, 角色扮演,多语种,韩语 | Momo | `ko_female_bv546_uranus_bigtts` | 韩语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 客服场景,多语种,韩语 | Minho | `ko_male_m03_uranus_bigtts` | 韩语 | male | QA | 情感变化、指令遵循 | — |
| 有声阅读, 教学场景, 视频配音,多语种,韩语 | Shane | `ko_male_shane_uranus_bigtts` | 韩语 | male | Context | 情感变化、上下文遵循 | 仅限单向流使用，不支持双向流，双向流调用会直接报错； |
| 通用场景, 教学场景,多语种,马来语 | Ham | `ms_male_ham_uranus_bigtts` | 马来语 | male | QA | 情感变化、指令遵循 | — |
| 通用场景, 客服场景,多语种,马来语 | Naim | `ms_male_naim_uranus_bigtts` | 马来语 | male | QA | 情感变化、指令遵循 | — |
| 教学场景, 视频配音,多语种,墨西哥西语 | Irene | `mx_female_bv065_uranus_bigtts` | 墨西哥西语 | female | QA | 情感变化、指令遵循 | — |
| 有声阅读,视频配音,多语种,墨西哥西语 | Diego | `mx_male_bv165dialogue_uranus_bigtts` | 墨西哥西语 | male | QA | 情感变化、指令遵循 | — |
| 有声阅读,视频配音,多语种,墨西哥西语 | Marcos | `mx_male_bv165narrator_uranus_bigtts` | 墨西哥西语 | male | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,多语种,墨西哥西语 | Lucy | `mx_female_bv166dialogue_uranus_bigtts` | 墨西哥西语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,多语种,墨西哥西语 | Rosa | `mx_female_bv166emotion_uranus_bigtts` | 墨西哥西语 | female | QA | 情感变化、指令遵循 | — |
| 有声阅读, 视频配音, 客服场景,多语种,墨西哥西语 | Freya | `mx_female_bv166narrator_uranus_bigtts` | 墨西哥西语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景,有声阅读,多语种,墨西哥西语 | Felipe | `mx_male_felipe_uranus_bigtts` | 墨西哥西语 | male | Context | 情感变化、上下文遵循 | 仅限单向流使用，不支持双向流，双向流调用会直接报错； |
| 教学场景, 视频配音,多语种,墨西哥西语 | Derek | `mx_male_ht_mx_m012_uranus_bigtts` | 墨西哥西语 | male | QA | 情感变化、指令遵循 | — |
| 通用场景, 客服场景,多语种,墨西哥西语 | Leslie | `mx_female_leslie_uranus_bigtts` | 墨西哥西语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,多语种,墨西哥西语 | Marcelo | `mx_male_marcelo_uranus_bigtts` | 墨西哥西语 | male | QA | 情感变化、指令遵循 | — |
| 通用场景, 客服场景,多语种,巴西葡萄牙语 | Sam | `pt_male_bv172_uranus_bigtts` | 巴西葡萄牙语 | male | QA | 情感变化、指令遵循 | — |
| 视频配音,多语种,巴西葡萄牙语 | Walter | `pt_male_bv172dialogue_uranus_bigtts` | 巴西葡萄牙语 | male | QA | 情感变化、指令遵循 | — |
| 教学场景, 视频配音,多语种,巴西葡萄牙语 | Vincent | `pt_male_bv172emotion_uranus_bigtts` | 巴西葡萄牙语 | male | QA | 情感变化、指令遵循 | — |
| 有声阅读, 角色扮演,多语种,巴西葡萄牙语 | Miles | `pt_male_bv172narrator_uranus_bigtts` | 巴西葡萄牙语 | male | QA | 情感变化、指令遵循 | — |
| 通用场景, 教学场景,多语种,巴西葡萄牙语 | Diana | `pt_female_bv173_uranus_bigtts` | 巴西葡萄牙语 | female | QA | 情感变化、指令遵循 | — |
| 视频配音, 客服场景,多语种,巴西葡萄牙语 | Elena | `pt_female_bv173dialogue_uranus_bigtts` | 巴西葡萄牙语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 教学场景,多语种,巴西葡萄牙语 | Lola | `pt_female_bv173emotion_uranus_bigtts` | 巴西葡萄牙语 | female | QA | 情感变化、指令遵循 | — |
| 视频配音, 客服场景,多语种,巴西葡萄牙语 | Emma | `pt_female_bv173narrator_uranus_bigtts` | 巴西葡萄牙语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,多语种,巴西葡萄牙语 | Sofia | `pt_female_bv530_uranus_bigtts` | 巴西葡萄牙语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 教学场景,多语种,巴西葡萄牙语 | Arthur | `pt_male_bv531_uranus_bigtts` | 巴西葡萄牙语 | male | QA | 情感变化、指令遵循 | — |
| 教学场景, 视频配音,多语种,巴西葡萄牙语 | Mari | `pt_female_mari_uranus_bigtts` | 巴西葡萄牙语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 教学场景,多语种,巴西葡萄牙语 | Toby | `pt_male_martins_uranus_bigtts` | 巴西葡萄牙语 | male | Context | 情感变化、上下文遵循 | 仅限单向流使用，不支持双向流，双向流调用会直接报错； |
| 教学场景, 视频配音,多语种,巴西葡萄牙语 | Rael | `pt_male_rael_uranus_bigtts` | 巴西葡萄牙语 | male | QA | 情感变化、指令遵循 | — |
| 有声阅读,视频配音,多语种,俄语 | Amelia | `ru_female_af07_uranus_bigtts` | 俄语 | female | QA | 情感变化、指令遵循 | — |
| 有声阅读,视频配音,多语种,俄语 | Irinae | `ru_female_irinae_uranus_bigtts` | 俄语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,多语种,俄语 | Pavel | `ru_male_pavel_uranus_bigtts` | 俄语 | male | QA | 情感变化、指令遵循 | — |
| 通用场景,多语种,俄语 | Ksenia | `ru_female_sophie_uranus_bigtts` | 俄语 | female | QA | 情感变化、指令遵循 | — |
| 趣味口音,多语种,俄语 | Silas | `ru_male_vlad_uranus_bigtts` | 俄语 | male | QA | 情感变化、指令遵循 | — |
| 教学场景, 视频配音,多语种,泰语 | Valeria | `th_female_bv568_angry_uranus_bigtts` | 泰语 | female | QA | 情感变化、指令遵循 | — |
| 有声阅读,视频配音,多语种,泰语 | Iris | `th_female_bv568_fear_uranus_bigtts` | 泰语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,多语种,泰语 | Zara | `th_female_bv568_happy_uranus_bigtts` | 泰语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,多语种,泰语 | Valentina | `th_female_bv568_hate_uranus_bigtts` | 泰语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,多语种,泰语 | Mildred | `th_female_bv568_neutral_uranus_bigtts` | 泰语 | female | QA | 情感变化、指令遵循 | — |
| 视频配音, 客服场景,多语种,泰语 | Lydia | `th_female_bv568_sad_uranus_bigtts` | 泰语 | female | QA | 情感变化、指令遵循 | — |
| 有声阅读,视频配音,多语种,泰语 | Phoebe | `th_female_bv568_suprise_uranus_bigtts` | 泰语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,多语种,菲律宾语 | Annika | `tl_female_annika_uranus_bigtts` | 菲律宾语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,多语种,菲律宾语 | Ed | `tl_male_ed_uranus_bigtts` | 菲律宾语 | male | QA | 情感变化、指令遵循 | — |
| 有声阅读, 视频配音, 客服场景,多语种,菲律宾语 | Hervie | `tl_female_hervie_uranus_bigtts` | 菲律宾语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 客服场景,多语种,越南语 | Hong | `vi_female_hong_uranus_bigtts` | 越南语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,多语种,越南语 | Ling | `vi_female_ling_uranus_bigtts` | 越南语 | female | QA | 情感变化、指令遵循 | — |
| 视频配音,多语种,越南语 | Linh | `vi_female_linh_uranus_bigtts` | 越南语 | female | QA | 情感变化、指令遵循 | — |
| 视频配音, 客服场景,多语种,越南语 | Partner | `vi_female_partner_uranus_bigtts` | 越南语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景,有声阅读, 角色扮演,多语种,越南语 | Ruan | `vi_female_ruan_uranus_bigtts` | 越南语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 视频配音,多语种,越南语 | Wu | `vi_female_wu_uranus_bigtts` | 越南语 | female | QA | 情感变化、指令遵循 | — |
| 通用场景, 客服场景,多语种,越南语 | Wumg | `vi_male_wumg_uranus_bigtts` | 越南语 | male | QA | 情感变化、指令遵循 | — |
| 通用场景, 教学场景,多语种,意大利语 | Enzo | `it_male_enzo_uranus_bigtts` | 意大利语 | male | Context | 情感变化、上下文遵循 | 仅限单向流使用，不支持双向流，双向流调用会直接报错； |

## 实现建议

1. 当前阶段只对明确识别为 `bytedance/seed-tts-2.0` 的模型返回上面的 93 个主表常规音色；OpenAI 模型继续使用 OpenAI 音色，ICL/S2S/1.0 使用各自的数据源。多语种表 151 项单独作为后续扩展。
2. 音色对象至少保留 `speakerId`、`displayName`、`language`、`group` 和 `restriction`，UI 展示名称与语言，网络请求只发送 `speakerId`。
3. 切换模型时先计算新模型音色清单；若当前值不存在，则同步切换为 `zh_female_vv_uranus_bigtts`，避免状态短暂保留 `alloy` 后触发请求。
4. 清单是 2026-08-03 官方页面快照。后续更新应重新对照同一官方页面，并以 Speaker ID 作为稳定键；展示名称可随文档更新。

## 来源

- 火山引擎：[音色列表](https://docs.volcengine.com/docs/6561/1257544?lang=zh)，最近更新时间 2026-08-03。
- 火山引擎：[模型列表](https://docs.volcengine.com/docs/6561/2499930?lang=zh)，用于确认 TTS 2.0、ICL 2.0 与 S2S 的边界。
- 火山引擎：[单向流式语音合成 HTTP](https://docs.volcengine.com/docs/6561/2528925?lang=zh)，用于确认资源 ID、必选 `speaker` 与官方示例默认音色。
