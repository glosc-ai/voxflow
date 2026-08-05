/// Metadata for a standard Volcengine Seed-TTS 2.0 speaker.
class VolcengineTtsVoice {
  const VolcengineTtsVoice({
    required this.speakerId,
    required this.displayName,
    required this.language,
    required this.scenario,
  });

  /// Value sent to the OpenAI-compatible `voice` request field.
  final String speakerId;

  /// Official display name from the Volcengine voice catalog.
  final String displayName;

  /// Official language description from the Volcengine voice catalog.
  final String language;

  /// Official usage scenario from the Volcengine voice catalog.
  final String scenario;
}

/// Embedded standard Seed-TTS 2.0 voice catalog published by Volcengine.
///
/// Source snapshot:
/// `docs/research/volcengine-seed-tts-2.0-voices.json` (93 entries).
abstract final class VolcengineTtsVoiceCatalog {
  static const productDefaultSpeakerId = 'zh_female_cancan_uranus_bigtts';

  /// Cancan stays first as the product default; all other entries retain the
  /// order in the official source snapshot.
  static const voices = <VolcengineTtsVoice>[
    VolcengineTtsVoice(
      speakerId: 'zh_female_cancan_uranus_bigtts',
      displayName: '知性灿灿 2.0',
      language: '中文',
      scenario: '角色扮演',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_vv_uranus_bigtts',
      displayName: 'Vivi 2.0',
      language: '语种：中文、日文、印尼、墨西哥西班牙语 / 方言：四川、陕西、东北',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_xiaohe_uranus_bigtts',
      displayName: '小何 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_m191_uranus_bigtts',
      displayName: '云舟 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_taocheng_uranus_bigtts',
      displayName: '小天 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_liufei_uranus_bigtts',
      displayName: '刘飞 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_sophie_uranus_bigtts',
      displayName: '魅力苏菲 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_qingxinnvsheng_uranus_bigtts',
      displayName: '清新女声 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_sajiaoxuemei_uranus_bigtts',
      displayName: '撒娇学妹 2.0',
      language: '中文',
      scenario: '角色扮演',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_tianmeixiaoyuan_uranus_bigtts',
      displayName: '甜美小源 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_tianmeitaozi_uranus_bigtts',
      displayName: '甜美桃子 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_shuangkuaisisi_uranus_bigtts',
      displayName: '爽快思思 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_peiqi_uranus_bigtts',
      displayName: '佩奇猪 2.0',
      language: '中文',
      scenario: '视频配音',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_linjianvhai_uranus_bigtts',
      displayName: '邻家女孩 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_shaonianzixin_uranus_bigtts',
      displayName: '少年梓辛 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_sunwukong_uranus_bigtts',
      displayName: '猴哥 2.0',
      language: '中文',
      scenario: '视频配音',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_yingyujiaoxue_uranus_bigtts',
      displayName: 'Tina老师 2.0',
      language: '中文、英式英语',
      scenario: '教育场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_kefunvsheng_uranus_bigtts',
      displayName: '暖阳女声 2.0',
      language: '中文',
      scenario: '客服场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_xiaoxue_uranus_bigtts',
      displayName: '儿童绘本 2.0',
      language: '中文',
      scenario: '有声阅读',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_dayi_uranus_bigtts',
      displayName: '大壹 2.0',
      language: '中文',
      scenario: '视频配音',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_mizai_uranus_bigtts',
      displayName: '黑猫侦探社咪仔 2.0',
      language: '中文',
      scenario: '视频配音',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_jitangnv_uranus_bigtts',
      displayName: '鸡汤女 2.0',
      language: '中文',
      scenario: '视频配音',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_meilinvyou_uranus_bigtts',
      displayName: '魅力女友 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_liuchangnv_uranus_bigtts',
      displayName: '流畅女声 2.0',
      language: '中文',
      scenario: '视频配音',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_ruyayichen_uranus_bigtts',
      displayName: '儒雅逸辰 2.0',
      language: '中文',
      scenario: '视频配音',
    ),
    VolcengineTtsVoice(
      speakerId: 'en_male_tim_uranus_bigtts',
      displayName: 'Tim',
      language: '美式英语',
      scenario: '多语种',
    ),
    VolcengineTtsVoice(
      speakerId: 'en_female_dacey_uranus_bigtts',
      displayName: 'Dacey',
      language: '美式英语',
      scenario: '多语种',
    ),
    VolcengineTtsVoice(
      speakerId: 'en_female_stokie_uranus_bigtts',
      displayName: 'Stokie',
      language: '美式英语',
      scenario: '多语种',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_wenroumama_uranus_bigtts',
      displayName: '温柔妈妈 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_jieshuoxiaoming_uranus_bigtts',
      displayName: '解说小明 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_tvbnv_uranus_bigtts',
      displayName: 'TVB女声 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_yizhipiannan_uranus_bigtts',
      displayName: '译制片男 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_qiaopinv_uranus_bigtts',
      displayName: '俏皮女声 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_zhishuaiyingzi_uranus_bigtts',
      displayName: '直率英子 2.0',
      language: '中文',
      scenario: '角色扮演',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_linjiananhai_uranus_bigtts',
      displayName: '邻家男孩 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_silang_uranus_bigtts',
      displayName: '四郎 2.0',
      language: '中文',
      scenario: '角色扮演',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_ruyaqingnian_uranus_bigtts',
      displayName: '儒雅青年 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_qingcang_uranus_bigtts',
      displayName: '擎苍 2.0',
      language: '中文',
      scenario: '角色扮演',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_xionger_uranus_bigtts',
      displayName: '熊二 2.0',
      language: '中文',
      scenario: '角色扮演',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_yingtaowanzi_uranus_bigtts',
      displayName: '樱桃丸子 2.0',
      language: '中文',
      scenario: '角色扮演',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_wennuanahu_uranus_bigtts',
      displayName: '温暖阿虎 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_naiqimengwa_uranus_bigtts',
      displayName: '奶气萌娃 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_popo_uranus_bigtts',
      displayName: '婆婆 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_gaolengyujie_uranus_bigtts',
      displayName: '高冷御姐 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_aojiaobazong_uranus_bigtts',
      displayName: '傲娇霸总 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_lanyinmianbao_uranus_bigtts',
      displayName: '懒音绵宝 2.0',
      language: '中文',
      scenario: '角色扮演',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_fanjuanqingnian_uranus_bigtts',
      displayName: '反卷青年 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_wenroushunv_uranus_bigtts',
      displayName: '温柔淑女 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_gufengshaoyu_uranus_bigtts',
      displayName: '古风少御 2.0',
      language: '中文',
      scenario: '角色扮演',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_huolixiaoge_uranus_bigtts',
      displayName: '活力小哥 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_baqiqingshu_uranus_bigtts',
      displayName: '霸气青叔 2.0',
      language: '中文',
      scenario: '有声阅读',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_xuanyijieshuo_uranus_bigtts',
      displayName: '悬疑解说 2.0',
      language: '中文',
      scenario: '有声阅读',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_mengyatou_uranus_bigtts',
      displayName: '萌丫头 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_tiexinnvsheng_uranus_bigtts',
      displayName: '贴心女声 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_jitangmei_uranus_bigtts',
      displayName: '鸡汤妹妹 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_cixingjieshuonan_uranus_bigtts',
      displayName: '磁性解说男声 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_liangsangmengzai_uranus_bigtts',
      displayName: '亮嗓萌仔 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_kailangjiejie_uranus_bigtts',
      displayName: '开朗姐姐 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_gaolengchenwen_uranus_bigtts',
      displayName: '高冷沉稳 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_shenyeboke_uranus_bigtts',
      displayName: '深夜播客 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_lubanqihao_uranus_bigtts',
      displayName: '鲁班七号 2.0',
      language: '中文',
      scenario: '角色扮演',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_jiaochuannv_uranus_bigtts',
      displayName: '娇喘女声 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_linxiao_uranus_bigtts',
      displayName: '林潇 2.0',
      language: '中文',
      scenario: '角色扮演',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_lingling_uranus_bigtts',
      displayName: '玲玲姐姐 2.0',
      language: '中文',
      scenario: '角色扮演',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_chunribu_uranus_bigtts',
      displayName: '春日部姐姐 2.0',
      language: '中文',
      scenario: '角色扮演',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_tangseng_uranus_bigtts',
      displayName: '唐僧 2.0',
      language: '中文',
      scenario: '角色扮演',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_zhuangzhou_uranus_bigtts',
      displayName: '庄周 2.0',
      language: '中文',
      scenario: '角色扮演',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_kailangdidi_uranus_bigtts',
      displayName: '开朗弟弟 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_zhubajie_uranus_bigtts',
      displayName: '猪八戒 2.0',
      language: '中文',
      scenario: '角色扮演',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_ganmaodianyin_uranus_bigtts',
      displayName: '感冒电音姐姐 2.0',
      language: '中文',
      scenario: '角色扮演',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_chanmeinv_uranus_bigtts',
      displayName: '谄媚女声 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_nvleishen_uranus_bigtts',
      displayName: '女雷神 2.0',
      language: '中文',
      scenario: '角色扮演',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_qinqienv_uranus_bigtts',
      displayName: '亲切女声 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_kuailexiaodong_uranus_bigtts',
      displayName: '快乐小东 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_kailangxuezhang_uranus_bigtts',
      displayName: '开朗学长 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_youyoujunzi_uranus_bigtts',
      displayName: '悠悠君子 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_wenjingmaomao_uranus_bigtts',
      displayName: '文静毛毛 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_zhixingnv_uranus_bigtts',
      displayName: '知性女声 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_qingshuangnanda_uranus_bigtts',
      displayName: '清爽男大 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_yuanboxiaoshu_uranus_bigtts',
      displayName: '渊博小叔 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_yangguangqingnian_uranus_bigtts',
      displayName: '阳光青年 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_qingchezizi_uranus_bigtts',
      displayName: '清澈梓梓 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_tianmeiyueyue_uranus_bigtts',
      displayName: '甜美悦悦 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_xinlingjitang_uranus_bigtts',
      displayName: '心灵鸡汤 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_wenrouxiaoge_uranus_bigtts',
      displayName: '温柔小哥 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_roumeinvyou_uranus_bigtts',
      displayName: '柔美女友 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_dongfanghaoran_uranus_bigtts',
      displayName: '东方浩然 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_wenrouxiaoya_uranus_bigtts',
      displayName: '温柔小雅 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_tiancaitongsheng_uranus_bigtts',
      displayName: '天才童声 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_wuzetian_uranus_bigtts',
      displayName: '武则天 2.0',
      language: '中文',
      scenario: '角色扮演',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_gujie_uranus_bigtts',
      displayName: '顾姐 2.0',
      language: '中文',
      scenario: '角色扮演',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_male_guanggaojieshuo_uranus_bigtts',
      displayName: '广告解说 2.0',
      language: '中文',
      scenario: '通用场景',
    ),
    VolcengineTtsVoice(
      speakerId: 'zh_female_shaoergushi_uranus_bigtts',
      displayName: '少儿故事 2.0',
      language: '中文',
      scenario: '有声阅读',
    ),
  ];

  static VolcengineTtsVoice? findBySpeakerId(String speakerId) {
    for (final voice in voices) {
      if (voice.speakerId == speakerId) {
        return voice;
      }
    }
    return null;
  }
}
