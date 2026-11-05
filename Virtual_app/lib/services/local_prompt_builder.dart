import 'dart:math' as math;

import '../models/character.dart';
import '../models/chat_message.dart';

/// 计数一段文本的 token 数（由本地引擎 tokenizer 注入，便于单测替换）。
typedef TokenCounter = Future<int> Function(String text);

/// 本地小模型（0.8B）单轮请求的组装结果。
///
/// 设计目标：**只给当前对话需要的内容**，用户输入是第一优先级。
/// - [systemPrompt] 是压缩后的角色卡（硬上限 [LocalPromptBuilder.maxSystemTokens]）。
/// - [history] 只含最近 [LocalPromptBuilder.recentTurns] 轮，且已按预算裁剪。
/// - [currentTurn] 是用户最新输入 + 本轮指令（极短输入会追加澄清提示）。
class LocalPromptPlan {
  final String systemPrompt;
  final List<Map<String, String>> history;
  final Map<String, String> currentTurn;

  final int systemTokens;
  final int historyTokens;
  final int historyBudget;
  final int droppedMessages;
  final bool shortInput;

  const LocalPromptPlan({
    required this.systemPrompt,
    required this.history,
    required this.currentTurn,
    required this.systemTokens,
    required this.historyTokens,
    required this.historyBudget,
    required this.droppedMessages,
    required this.shortInput,
  });

  /// system 由 Chat 创建时的 systemPrompt 承载，消息列表只放历史 + 本轮。
  List<Map<String, dynamic>> get fullMessages => [
        for (final m in history) {'role': m['role']!, 'content': m['content']!},
        {'role': currentTurn['role']!, 'content': currentTurn['content']!},
      ];

  /// 增量模式只发本轮（历史已留在引擎上下文里）。
  List<Map<String, dynamic>> get incrementalMessages => [
        {'role': currentTurn['role']!, 'content': currentTurn['content']!},
      ];
}

/// 本地模型提示词组装层（独立于 PromptService / 适配器）。
///
/// 真机问题背景：0.8B 小模型一次塞整张角色卡 + 全部历史 + 开场白后，
/// 会把「用户输入」当成续写素材，输出大段设定独白（例如只发「你是」却
/// 回复厨房/铁饭碗设定）。这里的策略：
/// 1. 角色卡只抽「名字 + 身份 + 一句话性格 + 口吻 + 2~3 条禁止项」，≤300 token；
/// 2. 历史只带最近 4 轮（8 条），并按 token 预算从最老丢；
/// 3. 顺序固定：system(压缩卡) → 最近历史 → 用户最新输入 → 本轮指令；
/// 4. 用户输入 ≤6 字时追加「先一句话回应或反问澄清」的提示；
/// 5. 开场白只是普通历史，进入窗口就带、超预算就丢。
class LocalPromptBuilder {
  /// 压缩角色卡硬上限（token）。
  static const int maxSystemTokens = 300;

  /// 最近保留的对话轮数（一轮 = 用户消息 + 其后的助手消息）。
  static const int recentTurns = 4;

  /// 极短输入阈值（字符数）。
  static const int shortInputChars = 6;

  /// 单条消息在 chat template 中的额外开销（role 标记、分隔符等）。
  static const int messageOverheadTokens = 4;

  /// 历史预算下限，避免极端参数下一条都放不下。
  static const int minHistoryBudget = 64;

  /// 本轮指令：明确要求直接回应用户这句话，禁止续写设定。
  static const String turnInstruction =
      '直接回应用户这句话。只写角色此刻的回应，不要复述角色设定，'
      '不要另起场景，不要续写其他角色的故事，不要代替用户行动。';

  /// 极短输入附加提示。
  static const String shortInputHint =
      '用户只说了很短的几个字，先用一句话回应或反问澄清，不要扩写场景。';

  /// 组装单轮本地请求。
  ///
  /// [contextSize] / [maxTokens] 取自端点配置；[countTokens] 注入引擎 tokenizer。
  /// [systemPromptOverride] 为会话级补充要求（可选，超长会被截断）。
  static Future<LocalPromptPlan> build({
    required Character character,
    required List<ChatMessage> history,
    required String userMessage,
    required TokenCounter countTokens,
    required int contextSize,
    required int maxTokens,
    String? systemPromptOverride,
  }) async {
    final systemPrompt = await compressCharacterCard(
      character: character,
      countTokens: countTokens,
      override: systemPromptOverride,
    );
    final systemTokens = await countTokens(systemPrompt);

    // 预算 = 上下文 − 输出预留 − 压缩卡占用，且历史只使用剩余空间的一半，
    // 另一半留给系统模板/生成长度波动。保证「总预算 ≤ ctx − maxTokens − system」。
    final free = contextSize - maxTokens - systemTokens;
    final historyBudget = math.max(minHistoryBudget, math.max(0, free) ~/ 2);

    final turns = _groupTurns(history);
    final droppedTurns = turns.length > recentTurns
        ? turns.sublist(0, turns.length - recentTurns)
        : const <List<ChatMessage>>[];
    var keptTurns = turns.length <= recentTurns
        ? turns
        : turns.sublist(turns.length - recentTurns);
    var dropped = droppedTurns.fold<int>(0, (acc, t) => acc + t.length);

    var costs = await _countTurns(keptTurns, countTokens);
    var total = _sum(costs);

    // 超预算：从最老的整轮开始丢（不切断 user/assistant 配对）
    while (total > historyBudget && keptTurns.length > 1) {
      dropped += keptTurns.first.length;
      keptTurns = keptTurns.sublist(1);
      costs = costs.sublist(1);
      total = _sum(costs);
    }

    // 只剩一轮仍超预算：截断该轮内容（保持配对，只压文字）
    List<Map<String, String>> historyMessages = [
      for (final turn in keptTurns)
        for (final m in turn) {'role': m.role.name, 'content': m.content},
    ];
    if (total > historyBudget && historyMessages.isNotEmpty) {
      historyMessages = await _truncateToBudget(
        historyMessages,
        historyBudget,
        countTokens,
      );
      costs = [for (final m in historyMessages) await _costOf(m, countTokens)];
      total = _sum(costs);
    }

    final trimmedInput = userMessage.trim();
    final shortInput = trimmedInput.runes.length <= shortInputChars;
    final currentTurn = <String, String>{
      'role': 'user',
      'content': _composeTurn(trimmedInput, shortInput),
    };

    return LocalPromptPlan(
      systemPrompt: systemPrompt,
      history: historyMessages,
      currentTurn: currentTurn,
      systemTokens: systemTokens,
      historyTokens: total,
      historyBudget: historyBudget,
      droppedMessages: dropped,
      shortInput: shortInput,
    );
  }

  /// 压缩角色卡：名字 + 身份 + 性格 + 场景 + 口吻 + 禁止项，硬上限 300 token。
  ///
  /// 逐级收缩（先砍场景/身份/性格长度），仍超限则按 token 二分截断，
  /// 保证返回值不会超过 [maxSystemTokens]。
  static Future<String> compressCharacterCard({
    required Character character,
    required TokenCounter countTokens,
    String? override,
  }) async {
    final name = _clean(character.name).isEmpty ? '角色' : _clean(character.name);
    final desc = _clean(character.description);
    final personality = _clean(character.personality);
    final scenario = _clean(character.scenario);
    final extra = _clean(override);

    // 三级收缩：从「较完整」逐步压到「只留骨架」
    final stages = <String>[
      _composeCard(
        name: name,
        identity: _clip(desc, 90),
        personality: _clip(personality, 60),
        scenario: _clip(scenario, 60),
        tone: _toneOf(personality, desc, character.systemPrompt),
        extra: _clip(extra, 40),
      ),
      _composeCard(
        name: name,
        identity: _clip(desc, 50),
        personality: _clip(personality, 40),
        scenario: '',
        tone: _toneOf(personality, desc, character.systemPrompt),
        extra: '',
      ),
      _composeCard(
        name: name,
        identity: _clip(desc, 30),
        personality: '',
        scenario: '',
        tone: '',
        extra: '',
      ),
    ];

    for (final card in stages) {
      if (await countTokens(card) <= maxSystemTokens) return card;
    }
    return truncateToTokens(stages.last, maxSystemTokens, countTokens);
  }

  /// 把文本截断到不超过 [maxTokens]（按 token 二分，保留前缀）。
  static Future<String> truncateToTokens(
    String text,
    int maxTokens,
    TokenCounter countTokens,
  ) async {
    if (text.isEmpty || maxTokens <= 0) return '';
    if (await countTokens(text) <= maxTokens) return text;
    var low = 0;
    var high = text.length;
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      final candidate = text.substring(0, mid);
      if (await countTokens(candidate) <= maxTokens) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low <= 0 ? '' : text.substring(0, low);
  }

  /// 本轮消息：用户原文 +（极短输入提示）+ 本轮指令。
  static String _composeTurn(String input, bool shortInput) {
    final buf = StringBuffer(input);
    if (shortInput) {
      buf.write('\n\n');
      buf.write(shortInputHint);
    }
    buf.write('\n\n');
    buf.write(turnInstruction);
    return buf.toString();
  }

  /// 分组：用户消息开启新一轮，其后的助手消息归属该轮；
  /// 开头没有用户的消息（开场白）自成一轮，裁剪时随最老轮次一起丢弃。
  static List<List<ChatMessage>> _groupTurns(List<ChatMessage> history) {
    final turns = <List<ChatMessage>>[];
    for (final m in history) {
      if (m.isHidden) continue;
      if (m.role == MessageRole.system) continue;
      final content = m.content.trim();
      if (content.isEmpty) continue;
      if (m.role == MessageRole.user) {
        turns.add([m]);
      } else {
        if (turns.isEmpty) turns.add([]);
        turns.last.add(m);
      }
    }
    return turns;
  }

  static Future<List<int>> _countTurns(
    List<List<ChatMessage>> turns,
    TokenCounter countTokens,
  ) async {
    final costs = <int>[];
    for (final turn in turns) {
      for (final m in turn) {
        costs.add(await _costOf(
          {'role': m.role.name, 'content': m.content},
          countTokens,
        ));
      }
    }
    return costs;
  }

  static Future<int> _costOf(
    Map<String, String> message,
    TokenCounter countTokens,
  ) async {
    final text = message['content'] ?? '';
    int tokens;
    try {
      tokens = await countTokens(text);
    } catch (_) {
      tokens = (text.length / 2).ceil();
    }
    return tokens + messageOverheadTokens;
  }

  static int _sum(List<int> values) =>
      values.fold<int>(0, (acc, v) => acc + v);

  /// 单轮超预算时截断文字（保持 role 顺序，只压内容长度）。
  static Future<List<Map<String, String>>> _truncateToBudget(
    List<Map<String, String>> messages,
    int budget,
    TokenCounter countTokens,
  ) async {
    final result = [for (final m in messages) Map<String, String>.from(m)];
    for (var i = 0; i < result.length; i++) {
      final others = <int>[];
      for (var j = 0; j < result.length; j++) {
        if (j == i) continue;
        others.add(await _costOf(result[j], countTokens));
      }
      final allowed = budget - _sum(others) - messageOverheadTokens;
      if (allowed <= 0) {
        result[i]['content'] = '';
        continue;
      }
      result[i]['content'] = await truncateToTokens(
        result[i]['content']!,
        allowed,
        countTokens,
      );
    }
    return result;
  }

  static String _composeCard({
    required String name,
    required String identity,
    required String personality,
    required String scenario,
    required String tone,
    required String extra,
  }) {
    final parts = <String>['你是「$name」。'];
    if (identity.isNotEmpty) {
      parts.add('身份：$identity。');
    } else {
      parts.add('身份：按名字与性格自然扮演。');
    }
    if (personality.isNotEmpty) parts.add('性格：$personality。');
    if (scenario.isNotEmpty) parts.add('场景：$scenario。');
    if (tone.isNotEmpty) parts.add('说话口吻：$tone。');
    if (extra.isNotEmpty) parts.add('补充要求：$extra。');
    parts.add('禁止：不要复述设定；不要续写用户或其他角色的故事；'
        '不要另起场景或替用户做决定。');
    return parts.join('');
  }

  static String _toneOf(
    String personality,
    String description,
    String? systemPrompt,
  ) {
    final prompt = _clean(systemPrompt);
    if (prompt.isNotEmpty && prompt.runes.length <= 60) {
      return '${_clip(prompt, 60)}，短句口语化';
    }
    if (personality.isNotEmpty) return '贴合上述性格，短句口语化，不用第三人称旁白';
    if (description.isNotEmpty) return '贴合身份，短句口语化，不用第三人称旁白';
    return '';
  }

  static String _clean(String? value) {
    if (value == null) return '';
    return value
        .replaceAll(RegExp(r'[#*_>`~]'), '')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _clip(String value, int maxChars) {
    if (value.isEmpty) return '';
    final runes = value.runes.toList();
    if (runes.length <= maxChars) return value;
    return '${String.fromCharCodes(runes.take(maxChars))}…';
  }
}
