/// Unified NOVITA AI Client with Round-Robin Load Balancing
/// Similar to GroqClient but for Novita AI API
/// 
/// Features:
/// - Round-robin model rotation for load balancing
/// - Automatic retry with progressive backoff
/// - Rate limit handling
/// - Configurable temperature and max tokens

import 'dart:convert';
import 'package:http/http.dart' as http;

class NovitaClient {
  final String apiKey;
  final List<String> models;
  final http.Client httpClient;
  int _currentModelIndex = 0;

  NovitaClient(this.apiKey, this.models) : httpClient = http.Client();

  /// Default NOVITA models for different use cases
  static List<String> get defaultModels => [
    'deepseek/deepseek-v4-pro',
    'deepseek/deepseek-v4-flash',
    'qwen/qwen3.5-27b',
    'moonshotai/kimi-k2.6'
  ];

  static List<String> get questGenerationModels => [
    'deepseek/deepseek-v4-pro', // Best for creative quest generation
    'qwen/qwen3.5-27b',         // Good for structured output
    'deepseek/deepseek-v4-flash', // Fast fallback
    'moonshotai/kimi-k2.6'      // Alternative fallback
  ];

  /// Round-robin model selection for load balancing
  String get currentModel {
    final model = models[_currentModelIndex];
    _currentModelIndex = (_currentModelIndex + 1) % models.length;
    return model;
  }

  /// Generate completion with automatic retry and model rotation
  Future<String?> generateCompletion(
    String prompt, {
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 1500,
    List<Map<String, dynamic>>? tools,
    String? toolChoice,
  }) async {
    const maxRetries = 3;
    
    for (int retryCount = 0; retryCount < maxRetries; retryCount++) {
      final selectedModel = currentModel;
      
      try {
        final messages = <Map<String, dynamic>>[
          if (systemPrompt != null) 
            {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': prompt}
        ];

        final requestBody = <String, dynamic>{
          'model': selectedModel,
          'messages': messages,
          'temperature': temperature,
          'max_tokens': maxTokens,
        };

        // Add tools if provided
        if (tools != null && tools.isNotEmpty) {
          requestBody['tools'] = tools;
          requestBody['tool_choice'] = toolChoice ?? 'auto';
        }

        final response = await httpClient.post(
          Uri.parse('https://api.novita.ai/openai/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final content = data['choices'][0]['message']['content'];
          return content;
        } else if (response.statusCode == 429) {
          final waitTime = 3 + ((retryCount + 1) * 2);
          await Future.delayed(Duration(seconds: waitTime));
          continue;
        } else {
          throw NovitaException('API error: ${response.statusCode}', response.body);
        }
      } catch (e) {
        if (retryCount < maxRetries - 1) {
          await Future.delayed(Duration(seconds: 2));
          continue;
        } else {
          rethrow;
        }
      }
    }
    
    return null;
  }

  /// Generate structured JSON completion (for quest generation)
  Future<Map<String, dynamic>?> generateJsonCompletion(
    String prompt, {
    String? systemPrompt,
    double temperature = 0.8, // Higher creativity for structured generation
    int maxTokens = 1500,
  }) async {
    final jsonSystemPrompt = (systemPrompt ?? '') + 
        '\n\nIMPORTANT: Always respond with valid JSON only. Do not include markdown formatting or explanations.';
    
    final completion = await generateCompletion(
      prompt,
      systemPrompt: jsonSystemPrompt,
      temperature: temperature,
      maxTokens: maxTokens,
    );

    if (completion == null) return null;

    try {
      // Clean up potential markdown formatting
      String jsonStr = completion.trim();
      if (jsonStr.startsWith('```json')) {
        jsonStr = jsonStr.substring(7);
      }
      if (jsonStr.endsWith('```')) {
        jsonStr = jsonStr.substring(0, jsonStr.length - 3);
      }
      
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Generate completion with conversation history
  Future<String?> generateWithHistory(
    String prompt,
    List<Map<String, String>> conversationHistory, {
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 1500,
  }) async {
    const maxRetries = 3;
    
    for (int retryCount = 0; retryCount < maxRetries; retryCount++) {
      final selectedModel = currentModel;
      
      try {
        final messages = <Map<String, dynamic>>[
          if (systemPrompt != null) 
            {'role': 'system', 'content': systemPrompt},
        ];
        
        // Add conversation history
        for (final entry in conversationHistory) {
          messages.add({
            'role': entry['role']!,
            'content': entry['content']!,
          });
        }
        
        // Add current prompt
        messages.add({'role': 'user', 'content': prompt});

        final response = await httpClient.post(
          Uri.parse('https://api.novita.ai/openai/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': selectedModel,
            'messages': messages,
            'temperature': temperature,
            'max_tokens': maxTokens,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['choices'][0]['message']['content'];
        } else if (response.statusCode == 429) {
          final waitTime = 3 + ((retryCount + 1) * 2);
          await Future.delayed(Duration(seconds: waitTime));
          continue;
        } else {
          throw NovitaException('API error: ${response.statusCode}', response.body);
        }
      } catch (e) {
        if (retryCount < maxRetries - 1) {
          await Future.delayed(Duration(seconds: 2));
          continue;
        } else {
          rethrow;
        }
      }
    }
    
    return null;
  }

  void dispose() {
    httpClient.close();
  }
}

class NovitaException implements Exception {
  final String message;
  final String? responseBody;
  
  NovitaException(this.message, [this.responseBody]);
  
  @override
  String toString() => 'NovitaException: $message${responseBody != null ? '\nResponse: $responseBody' : ''}';
}

/// Factory methods for common use cases
class NovitaClientFactory {
  /// Create client optimized for quest generation
  static NovitaClient forQuestGeneration(String apiKey) {
    return NovitaClient(apiKey, NovitaClient.questGenerationModels);
  }

  /// Create client with default models
  static NovitaClient withDefaults(String apiKey) {
    return NovitaClient(apiKey, NovitaClient.defaultModels);
  }

  /// Create client with custom models
  static NovitaClient withModels(String apiKey, List<String> models) {
    return NovitaClient(apiKey, models);
  }
}