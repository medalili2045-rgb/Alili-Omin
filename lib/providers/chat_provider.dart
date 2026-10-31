import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../services/chat_service.dart';

class Message {
  final String id;
  final String text;
  final bool isUser;
  Message({required this.text, required this.isUser}) : id = const Uuid().v4();
}

class ChatState {
  final List<Message> messages;
  final bool isLoading;
  final String selectedModel;
  final bool useSearch;
  final bool useThinking;

  ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.selectedModel = 'deepseek/deepseek-r1:free',
    this.useSearch = false,
    this.useThinking = false,
  });

  ChatState copyWith({
    List<Message>? messages,
    bool? isLoading,
    String? selectedModel,
    bool? useSearch,
    bool? useThinking,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      selectedModel: selectedModel ?? this.selectedModel,
      useSearch: useSearch ?? this.useSearch,
      useThinking: useThinking ?? this.useThinking,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier() : super(ChatState(messages: [
    Message(text: 'أهلاً بك! أنا Alili Omni v4.0. كيف أساعدك اليوم؟', isUser: false)
  ]));

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || state.isLoading) return;

    // 1. إضافة رسالة المستخدم
    final userMsg = Message(text: text, isUser: true);
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
    );

    // 2. تجهيز السجل (History)
    final history = state.messages.map((m) => {
      'role': m.isUser ? 'user' : 'assistant',
      'content': m.text,
    }).toList();

    // 3. إرسال الطلب
    final reply = await ChatService.sendMessage(
      message: text,
      model: state.selectedModel,
      history: history,
      search: state.useSearch,
      thinking: state.useThinking,
    );

    // 4. إضافة رد المساعد
    state = state.copyWith(
      messages: [...state.messages, Message(text: reply, isUser: false)],
      isLoading: false,
    );
  }

  void setModel(String model) => state = state.copyWith(selectedModel: model);
  void toggleSearch() => state = state.copyWith(useSearch: !state.useSearch);
  void toggleThinking() => state = state.copyWith(useThinking: !state.useThinking);
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) => ChatNotifier());
