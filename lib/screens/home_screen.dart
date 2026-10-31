import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../providers/chat_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    
    ref.read(chatProvider.notifier).sendMessage(text);
    _controller.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);
    ref.listen(chatProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        title: const Text('Alili Omni', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          DropdownButton<String>(
            value: state.selectedModel,
            dropdownColor: const Color(0xFF141414),
            underline: const SizedBox(),
            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00E5FF)),
            items: const [
              DropdownMenuItem(value: 'deepseek/deepseek-r1:free', child: Text('DeepSeek R1', style: TextStyle(fontSize: 12, color: Colors.white))),
              DropdownMenuItem(value: 'qwen/qwen3-235b-a22b:free', child: Text('Qwen 235B', style: TextStyle(fontSize: 12, color: Colors.white))),
              DropdownMenuItem(value: 'gemini-3.8-flash', child: Text('Gemini 3.8', style: TextStyle(fontSize: 12, color: Colors.white))),
            ],
            onChanged: (val) => ref.read(chatProvider.notifier).setModel(val!),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: state.messages.length,
              itemBuilder: (context, i) {
                final msg = state.messages[i];
                return Align(
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(14),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.80),
                    decoration: BoxDecoration(
                      color: msg.isUser ? const Color(0xFF1E1E24) : const Color(0xFF141414),
                      borderRadius: BorderRadius.circular(20),
                      border: msg.isUser ? null : Border.all(color: const Color(0xFF2A2A2A)),
                    ),
                    child: msg.isUser 
                        ? Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 15))
                        : MarkdownBody(
                            data: msg.text,
                            styleSheet: MarkdownStyleSheet(
                              p: const TextStyle(color: Colors.white70, fontSize: 15),
                              code: const TextStyle(backgroundColor: Colors.black45, color: Color(0xFF00E5FF)),
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
          if (state.isLoading) 
            const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator(color: Color(0xFF00E5FF))),
          
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF0A0A0A),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildToggle(Icons.search, 'بحث', state.useSearch, () => ref.read(chatProvider.notifier).toggleSearch()),
                    const SizedBox(width: 8),
                    _buildToggle(Icons.psychology, 'تفكير', state.useThinking, () => ref.read(chatProvider.notifier).toggleThinking()),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'اسأل عن أي شيء...',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF141414),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFF00E5FF),
                      child: IconButton(icon: const Icon(Icons.arrow_upward, color: Colors.black), onPressed: _send),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF00E5FF).withOpacity(0.2) : const Color(0xFF141414),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? const Color(0xFF00E5FF) : const Color(0xFF2A2A2A)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isActive ? const Color(0xFF00E5FF) : Colors.white54),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: isActive ? const Color(0xFF00E5FF) : Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
