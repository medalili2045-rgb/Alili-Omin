import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('chatHistory');
  await Hive.openBox('settings');
  runApp(const AliliOmniApp());
}

class AliliOmniApp extends StatelessWidget {
  const AliliOmniApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alili Omni',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        colorScheme: const ColorScheme.dark(primary: Color(0xFF00E5FF), surface: Color(0xFF141414)),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const ChatScreen(),
    const ImageScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF141414),
        indicatorColor: const Color(0xFF00E5FF).withOpacity(0.2),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble, color: Color(0xFF00E5FF)), label: 'الدردشة'),
          NavigationDestination(icon: Icon(Icons.image_outlined), selectedIcon: Icon(Icons.image, color: Color(0xFF00E5FF)), label: 'الصور'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings, color: Color(0xFF00E5FF)), label: 'الإعدادات'),
        ],
      ),
    );
  }
}

// ==================== 1. شاشة الدردشة ====================
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final box = Hive.box('chatHistory');
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  
  // الرابط الخاص بك
  final String workerUrl = 'https://alili-omni.medalili2045.workers.dev';
  
  String _selectedModel = 'gemini';

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  void _loadMessages() {
    final raw = box.get('messages', defaultValue: <dynamic>[]) as List;
    _messages = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    if (_messages.isEmpty) {
      _messages.add({'text': 'أهلاً بك! أنا Alili Omni. كيف أساعدك اليوم؟', 'isUser': false});
    }
    setState(() {});
  }

  void _addMessage(String text, bool isUser) {
    setState(() {
      _messages.add({'text': text, 'isUser': isUser});
      box.put('messages', _messages);
    });
    _scrollToBottom();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;
    _addMessage(text, true);
    _isLoading = true;
    _controller.clear();
    setState(() {});

    try {
      final history = _messages.map((m) => {
        'role': m['isUser'] ? 'user' : 'assistant',
        'content': m['text'],
      }).toList();

      final response = await http.post(
        Uri.parse(workerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': text,
          'model': _selectedModel,
          'history': history,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['reply'] != null) {
          _addMessage(data['reply'], false);
        } else {
          _addMessage('عذراً، حدث خطأ: ${data['error']}', false);
        }
      } else {
        _addMessage('مشكلة في الخادم (كود ${response.statusCode})', false);
      }
    } catch (e) {
      // إظهار الخطأ الحقيقي
      _addMessage('الخطأ الحقيقي: $e', false);
    } finally {
      _isLoading = false;
      setState(() {});
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        title: const Text('Alili Omni', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          DropdownButton<String>(
            value: _selectedModel,
            dropdownColor: const Color(0xFF141414),
            underline: const SizedBox(),
            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00E5FF)),
            items: const [
              DropdownMenuItem(value: 'gemini', child: Text('Gemini (عام)', style: TextStyle(color: Colors.white, fontSize: 13))),
              DropdownMenuItem(value: 'deepseek', child: Text('DeepSeek (برمجة)', style: TextStyle(color: Colors.white, fontSize: 13))),
              DropdownMenuItem(value: 'inkling', child: Text('Inkling (تحليل)', style: TextStyle(color: Colors.white, fontSize: 13))),
            ],
            onChanged: (val) => setState(() => _selectedModel = val!),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            onPressed: () {
              box.clear();
              setState(() => _messages.clear());
              _loadMessages();
            },
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, i) {
                  final m = _messages[i];
                  final isUser = m['isUser'] as bool;
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.80),
                      decoration: BoxDecoration(
                        color: isUser ? const Color(0xFF1E1E24) : const Color(0xFF141414),
                        borderRadius: BorderRadius.circular(24),
                        border: isUser ? null : Border.all(color: const Color(0xFF2A2A2A), width: 1),
                      ),
                      child: isUser 
                        ? Text(m['text'], style: const TextStyle(color: Colors.white, fontSize: 15))
                        : MarkdownBody(
                            data: m['text'],
                            styleSheet: MarkdownStyleSheet(
                              p: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                              code: const TextStyle(backgroundColor: Colors.black45, color: Color(0xFF00E5FF)),
                            ),
                          ),
                    ),
                  );
                },
              ),
            ),
            if (_isLoading) const Padding(padding: EdgeInsets.all(8.0), child: Text('Alili يكتب... ✍️', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12))),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(30), border: Border.all(color: const Color(0xFF2A2A2A))),
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(hintText: 'اسأل عن أي شيء...', hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(radius: 24, backgroundColor: const Color(0xFF00E5FF), child: IconButton(icon: const Icon(Icons.arrow_upward, color: Colors.black), onPressed: _send)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 2. شاشة الصور ====================
class ImageScreen extends StatefulWidget {
  const ImageScreen({super.key});
  @override
  State<ImageScreen> createState() => _ImageScreenState();
}

class _ImageScreenState extends State<ImageScreen> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  Uint8List? _imageData;
  final String workerUrl = 'https://alili-omni.medalili2045.workers.dev';

  Future<void> _generate() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty) return;
    setState(() { _isLoading = true; _imageData = null; });

    try {
      final response = await http.post(
        Uri.parse(workerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': prompt, 'type': 'image'}),
      );
      if (response.statusCode == 200) {
        setState(() => _imageData = response.bodyBytes);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل توليد الصورة.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('الخطأ: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استوديو الصور'), backgroundColor: const Color(0xFF0A0A0A)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'صف الصورة (مثال: قطة رائد فضاء)...',
                filled: true, fillColor: const Color(0xFF141414),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                suffixIcon: IconButton(icon: const Icon(Icons.auto_awesome, color: Color(0xFF00E5FF)), onPressed: _generate),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
                : _imageData != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.memory(_imageData!, fit: BoxFit.contain))
                  : const Center(child: Text('اكتب وصفاً لتوليد صورة 🎨', style: TextStyle(color: Colors.white54))),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 3. الإعدادات ====================
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات'), backgroundColor: const Color(0xFF0A0A0A)),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.info_outline, color: Colors.blueAccent),
            title: Text('عن التطبيق', style: TextStyle(color: Colors.white)),
            subtitle: Text('Alili Omni v3.0\nمحرك ذكاء اصطناعي متعدد النماذج', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }
}
