import 'dart:math';

/// A canned answer. [suggestions] renders the "Quick reply suggestions" card.
class PrebuiltAnswer {
  const PrebuiltAnswer(this.text, {this.suggestionsTitle, this.suggestions = const []});
  final String text;
  final String? suggestionsTitle;
  final List<QuickSuggestion> suggestions;
}

class QuickSuggestion {
  const QuickSuggestion(this.emoji, this.label, {this.prompt, this.url});
  final String emoji;
  final String label;
  final String? prompt; // sends this as a new message
  final String? url; // or opens a link

  Map<String, dynamic> toJson() => {'emoji': emoji, 'label': label, 'prompt': prompt, 'url': url};
  factory QuickSuggestion.fromJson(Map<String, dynamic> j) =>
      QuickSuggestion(j['emoji'] as String? ?? '•', j['label'] as String,
          prompt: j['prompt'] as String?, url: j['url'] as String?);
}

/// Instant, offline answers to common questions — zero latency, no network.
class PrebuiltAnswers {
  PrebuiltAnswers._();

  static const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];
  static final _rng = Random();

  static String _pick(List<String> o) => o[_rng.nextInt(o.length)];

  static String _time(DateTime n) {
    final h = n.hour % 12 == 0 ? 12 : n.hour % 12;
    return '$h:${n.minute.toString().padLeft(2, '0')} ${n.hour < 12 ? 'AM' : 'PM'}';
  }

  static String _date(DateTime n) => '${_weekdays[n.weekday - 1]}, ${_months[n.month - 1]} ${n.day}, ${n.year}';

  static PrebuiltAnswer? match(String raw, {String? userName}) {
    final q = raw.toLowerCase().trim().replaceAll(RegExp(r'[!?.,]+$'), '');
    final name = userName == null ? '' : ' $userName';
    final now = DateTime.now();

    bool has(String pattern) => RegExp(pattern).hasMatch(q);

    if (has(r'^(hi|hello|hey|yo|hiya|salut|bonjour|salam|good (morning|afternoon|evening))\b') &&
        q.split(' ').length <= 4) {
      return PrebuiltAnswer(_pick([
        'Hey$name! 👋 How can I assist you today?',
        'Hello$name! What can I help you with?',
        'Hi$name! Ready when you are — ask me anything, or try generating an image.',
      ]));
    }
    if (has(r'how are you|how r u|how\x27s it going|how are u')) {
      return const PrebuiltAnswer("I'm running smoothly and ready to help! ✨ What are we working on today?");
    }
    if (has(r'(what\x27?s|what is) (the )?time|what time is it|current time')) {
      return PrebuiltAnswer('It\'s **${_time(now)}** right now (${now.timeZoneName}).');
    }
    if (has(r'(what\x27?s|what is) (the |today\x27?s )?date|what day is (it|today)|today\x27?s date')) {
      return PrebuiltAnswer('Today is **${_date(now)}**.');
    }
    if (has(r'who are you|what are you|your name|what\x27?s your name')) {
      return const PrebuiltAnswer(
          "I'm **Podia**, the assistant inside Chatpodia. I can chat, answer questions, write, brainstorm, generate images, build mini web apps, and make short motion clips — by text or voice.");
    }
    if (has(r'what can you do|help me|^help$|your features|capabilities')) {
      return const PrebuiltAnswer(
        "Here's what I can do for you:\n\n"
        "- 💬 **Chat & answer** anything, with memory of the conversation\n"
        "- 🎨 **Generate images** — try *\"Generate an image of a neon forest\"*\n"
        "- 🌐 **Build web pages & mini apps** — *\"Build a tip calculator app\"*\n"
        "- 🎬 **Motion clips** — *\"Make a video of a sunrise over Tunis\"*\n"
        "- 🎙️ **Voice mode** — tap the waveform and just talk\n"
        "- 📚 **Stories, novels & poems**, summaries, translations and code",
        suggestionsTitle: 'Try one of these',
        suggestions: [
          QuickSuggestion('🎨', 'Generate an image', prompt: 'Generate an image of a futuristic green city at dusk'),
          QuickSuggestion('🌐', 'Build a mini app', prompt: 'Build a beautiful to-do list web app'),
          QuickSuggestion('🎬', 'Make a motion clip', prompt: 'Make a short video of waves on a beach at sunset'),
        ],
      );
    }
    if (has(r'^(thanks|thank you|thx|ty|merci|appreciate)')) {
      return PrebuiltAnswer(_pick(['Anytime! 😊', 'You\'re welcome$name!', 'Happy to help — anything else?']));
    }
    if (has(r'^(bye|goodbye|see you|good night|gn)\b')) {
      return PrebuiltAnswer(_pick(['Goodbye$name! Talk soon. 👋', 'See you later! 🌙', 'Take care$name!']));
    }
    if (has(r'tell me a joke|a joke|make me laugh')) {
      return PrebuiltAnswer(_pick([
        'Why do programmers prefer dark mode? Because light attracts bugs. 🐛',
        "I told my computer I needed a break, and it said: \"No problem — I'll go to sleep.\" 💤",
        'Why did the robot go on vacation? It needed to recharge its batteries. 🔋',
      ]));
    }
    if (has(r'who (made|created|built) you')) {
      return const PrebuiltAnswer(
          'I was built as part of **Chatpodia**, crafted in Flutter with a liquid-glass interface. 💚');
    }
    if (has(r'^(recommended )?music$|(play|recommend|suggest)\b.{0,30}\b(music|playlist|songs?)')) {
      return const PrebuiltAnswer(
        'How can I assist you today? Here are some picks to get you in the zone:',
        suggestionsTitle: 'Quick reply suggestions',
        suggestions: [
          QuickSuggestion('🎧', 'Lofi Beats', url: 'https://www.youtube.com/results?search_query=lofi+beats+to+study'),
          QuickSuggestion('🎧', 'Nature & Ambient Sounds',
              url: 'https://www.youtube.com/results?search_query=nature+ambient+sounds'),
          QuickSuggestion('🔥', 'Motivational & Classical',
              url: 'https://www.youtube.com/results?search_query=motivational+classical+music'),
        ],
      );
    }
    return null;
  }
}
