import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Gemini API client for fallback when GROQ fails
class GeminiClient {
  final String apiKey;
  final http.Client httpClient;
  
  static const String baseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  static const List<String> defaultModels = [
    'gemini-2.5-flash',
    'gemini-2.5-pro',
    'gemini-pro',
  ];
  
  String _currentModel = defaultModels.first;
  int _currentModelIndex = 0;

  GeminiClient(this.apiKey, {http.Client? httpClient}) 
      : httpClient = httpClient ?? http.Client();

  String get currentModel => _currentModel;

  /// Rotate to next model for load balancing/fallback
  void rotateModel() {
    _currentModelIndex = (_currentModelIndex + 1) % defaultModels.length;
    _currentModel = defaultModels[_currentModelIndex];
  }

  /// Generate completion using Gemini API
  Future<String?> generateCompletion(
    String prompt, {
    String? systemPrompt,
    int maxTokens = 800,
    double temperature = 0.7,
  }) async {
    try {
      final messages = <Map<String, dynamic>>[];
      
      if (systemPrompt != null) {
        messages.add({
          'role': 'user',
          'parts': [{'text': systemPrompt}]
        });
        messages.add({
          'role': 'model', 
          'parts': [{'text': 'I understand. I will follow these instructions.'}]
        });
      }
      
      messages.add({
        'role': 'user',
        'parts': [{'text': prompt}]
      });

      final response = await httpClient.post(
        Uri.parse('$baseUrl/models/$_currentModel:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': messages,
          'generationConfig': {
            'maxOutputTokens': maxTokens,
            'temperature': temperature,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            return parts[0]['text'] as String?;
          }
        }
      }
    } catch (e) {
      // Silent error handling
    }
    
    return null;
  }

  /// Generate completion with tool calling support (Gemini function calling)
  Future<Map<String, dynamic>?> generateCompletionWithTools(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools, {
    double temperature = 0.7,
    int maxTokens = 800,
  }) async {
    try {
      // Convert OpenAI-style messages to Gemini format
      final geminiContents = _convertMessagesToGeminiFormat(messages);
      
      // Convert OpenAI-style tools to Gemini function declarations
      final geminiTools = _convertToolsToGeminiFormat(tools);

      final response = await httpClient.post(
        Uri.parse('$baseUrl/models/$_currentModel:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': geminiContents,
          'tools': geminiTools.isNotEmpty ? [{'functionDeclarations': geminiTools}] : null,
          'generationConfig': {
            'maxOutputTokens': maxTokens,
            'temperature': temperature,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _convertGeminiResponseToOpenAIFormat(data);
      }
    } catch (e) {
      // Silent error handling
    }
    
    return null;
  }

  /// Convert OpenAI-style messages to Gemini format
  List<Map<String, dynamic>> _convertMessagesToGeminiFormat(List<Map<String, dynamic>> messages) {
    final geminiContents = <Map<String, dynamic>>[];
    
    for (final message in messages) {
      final role = message['role'] as String;
      final content = message['content'] as String;
      
      // Map OpenAI roles to Gemini roles
      String geminiRole;
      switch (role) {
        case 'system':
        case 'user':
          geminiRole = 'user';
          break;
        case 'assistant':
          geminiRole = 'model';
          break;
        default:
          geminiRole = 'user';
      }
      
      geminiContents.add({
        'role': geminiRole,
        'parts': [{'text': content}]
      });
    }
    
    return geminiContents;
  }

  /// Convert OpenAI-style tools to Gemini function declarations
  List<Map<String, dynamic>> _convertToolsToGeminiFormat(List<Map<String, dynamic>> tools) {
    final geminiTools = <Map<String, dynamic>>[];
    
    for (final tool in tools) {
      if (tool['type'] == 'function') {
        final function = tool['function'] as Map<String, dynamic>;
        
        geminiTools.add({
          'name': function['name'],
          'description': function['description'],
          'parameters': function['parameters'],
        });
      }
    }
    
    return geminiTools;
  }

  /// Convert Gemini response to OpenAI-compatible format
  Map<String, dynamic> _convertGeminiResponseToOpenAIFormat(Map<String, dynamic> geminiResponse) {
    final candidates = geminiResponse['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      return {'choices': []};
    }

    final candidate = candidates[0];
    final content = candidate['content'];
    final parts = content['parts'] as List?;
    
    if (parts == null || parts.isEmpty) {
      return {'choices': []};
    }

    // Check for function calls
    final functionCalls = <Map<String, dynamic>>[];
    String? textContent;
    
    for (final part in parts) {
      if (part['functionCall'] != null) {
        final functionCall = part['functionCall'];
        functionCalls.add({
          'id': 'call_${DateTime.now().millisecondsSinceEpoch}',
          'type': 'function',
          'function': {
            'name': functionCall['name'],
            'arguments': jsonEncode(functionCall['args'] ?? {}),
          },
        });
      } else if (part['text'] != null) {
        textContent = part['text'];
      }
    }

    final message = <String, dynamic>{
      'role': 'assistant',
      'content': textContent,
    };

    if (functionCalls.isNotEmpty) {
      message['tool_calls'] = functionCalls;
    }

    return {
      'choices': [
        {
          'message': message,
          'finish_reason': 'stop',
        }
      ]
    };
  }

  void dispose() {
    httpClient.close();
  }
}

/// Factory for creating Gemini clients
class GeminiClientFactory {
  static GeminiClient create(String apiKey) {
    return GeminiClient(apiKey);
  }
  
  /// Create from environment (for development/testing only)
  /// Not recommended for production packages
  static GeminiClient? createFromEnvironment() {
    final apiKey = Platform.environment['GEMINI_API_KEY'];
    if (apiKey != null && apiKey.isNotEmpty) {
      return GeminiClient(apiKey);
    }
    return null;
  }
}