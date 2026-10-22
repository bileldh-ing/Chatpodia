import 'dart:async';

import 'package:chatpodia/services/ai_service.dart';

/// Scripted replies used only by the demo-video recorder.
class DemoAiClient implements AiClient {
  DemoAiClient(this.assets);
  final String assets;

  static const _quantum = '''Imagine a **magic coin**

A normal computer uses **bits** — tiny switches that are either **0** or **1**, like a coin lying heads *or* tails.

A quantum computer uses **qubits**. A qubit is like a coin **spinning in the air** — it's a bit of heads *and* tails at the same time. That's called **superposition**.

**Why it matters**
- Many spinning coins can explore lots of answers at once
- Qubits can be *entangled*: flip one, and its partner reacts instantly
- Great for designing medicines, new materials and super-secure codes

So: normal computers check paths **one by one** — quantum computers try **many paths together**.''';

  static const _python = '''Here's a tiny **quantum coin flip** using Qiskit:

```python
from qiskit import QuantumCircuit
from qiskit_aer import AerSimulator

qc = QuantumCircuit(1, 1)
qc.h(0)          # put the qubit in superposition
qc.measure(0, 0) # look at the coin

result = AerSimulator().run(qc, shots=1000).result()
print(result.get_counts())  # ≈ {'0': 500, '1': 500}
```

Run it and you'll get **heads about half the time** — that's superposition in action.''';

  static const _plant = '''That's a **Monstera deliciosa** — and it looks healthy!

**Care tips**
- **Light:** bright, indirect sun — keep it out of harsh afternoon rays
- **Water:** when the top 5 cm of soil is dry (about weekly)
- **Temperature:** 18–27 °C, away from cold drafts
- **Extra:** give it a moss pole so those split leaves keep growing big''';

  static const _html = '''```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Pomodoro</title>
<style>
  body{margin:0;height:100vh;display:grid;place-items:center;background:#0b1c22;color:#e9fff7;font-family:system-ui}
  .ring{width:220px;height:220px;border-radius:50%;display:grid;place-items:center;
        background:conic-gradient(#3fe0b0 var(--p),#ffffff14 0);transition:.3s}
  .ring div{width:190px;height:190px;border-radius:50%;background:#0b1c22;display:grid;place-items:center;font-size:44px}
  button{margin:8px;padding:12px 22px;border:0;border-radius:14px;background:#2fd9a8;color:#04261c;font-weight:700}
</style>
</head>
<body>
  <main>
    <div class="ring" id="r" style="--p:0%"><div id="t">25:00</div></div>
    <p><button onclick="start()">Start</button><button onclick="pause()">Pause</button><button onclick="reset()">Reset</button></p>
  </main>
<script>
let left=1500,timer=null;
const draw=()=>{t.textContent=String(left/60|0).padStart(2,'0')+':'+String(left%60).padStart(2,'0');
  r.style.setProperty('--p',(100-left/15)+'%')};
function start(){if(!timer)timer=setInterval(()=>{if(left>0){left--;draw()}},1000)}
function pause(){clearInterval(timer);timer=null}
function reset(){pause();left=1500;draw()}
</script>
</body>
</html>
```''';

  @override
  bool get supportsVision => true;

  @override
  Stream<String> streamChat(List<ChatTurn> history, {String? system}) async* {
    final q = history.last.content.toLowerCase();
    String text;
    if ((system ?? '').contains('front-end engineer')) {
      text = _html;
    } else if (q.contains('quantum') && q.contains('python')) {
      text = _python;
    } else if (q.contains('quantum')) {
      text = _quantum;
    } else if (q.contains('plant')) {
      text = _plant;
    } else {
      text = 'Sure! Here is a quick, helpful answer.';
    }
    final parts = RegExp(r'\S+\s*').allMatches(text).map((m) => m.group(0)!).toList();
    await Future<void>.delayed(const Duration(milliseconds: 1500)); // "thinking"
    for (var i = 0; i < parts.length; i += 2) {
      await Future<void>.delayed(const Duration(milliseconds: 45));
      yield parts.skip(i).take(2).join();
    }
  }

  @override
  String imageUrl(String prompt, {int width = 1024, int height = 1024, int? seed}) {
    if (prompt.contains('frame:')) return '$assets/${prompt.split('frame:').last.trim()}.jpg';
    return '$assets/island.jpg';
  }

  @override
  Future<String> titleFor(String firstMessage) async {
    final q = firstMessage.toLowerCase();
    if (q.contains('quantum')) return 'Quantum computing for kids';
    if (q.contains('island')) return 'Floating island village';
    if (q.contains('playlist')) return 'Study playlist';
    return 'New chat';
  }

  @override
  Future<List<String>> storyboard(String idea) async => ['frame: f1', 'frame: f2', 'frame: f3', 'frame: f4'];
}
