/// Unified GROQ API Client with Round-Robin Load Balancing
/// Extracted from v8 MCP system for ecosystem-wide reuse
/// 
/// Features:
/// - Round-robin model rotation for load balancing
/// - Automatic retry with progressive backoff
/// - Rate limit handling
/// - Configurable temperature and max tokens

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class GroqClient {
  final String apiKey;
  final List<String> models;
  final http.Client httpClient;
  int _currentModelIndex = 0;

  GroqClient(this.apiKey, this.models) : httpClient = http.Client();

  /// Default GROQ models for different use cases
  static List<String> get defaultModels => [
    'llama-3.3-70b-versatile',
    'llama-3.1-8b-instant', 
    'gemma2-9b-it',
    'mixtral-8x7b-32768'
  ];

  static List<String> get questGenerationModels => [
    'llama-3.3-70b-versatile', // Best for creative quest generation
    'mixtral-8x7b-32768',      // Good for structured output
    'llama-3.1-8b-instant',    // Fast fallback
    'gemma2-9b-it'             // Alternative fallback
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
      print('🤖 Using GROQ model: $selectedModel (attempt ${retryCount + 1}/$maxRetries)');
      
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
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final content = data['choices'][0]['message']['content'];
          print('✅ GROQ completion successful with $selectedModel');
          return content;
        } else if (response.statusCode == 429) {
          final waitTime = 3 + ((retryCount + 1) * 2);
          print('⏳ Rate limit hit, waiting ${waitTime}s before retry');
          await Future.delayed(Duration(seconds: waitTime));
          continue;
        } else {
          print('❌ GROQ API Error: ${response.statusCode} - ${response.body}');
          throw GroqException('API error: ${response.statusCode}', response.body);
        }
      } catch (e) {
        if (retryCount < maxRetries - 1) {
          print('🔄 Retrying GROQ request: $e');
          await Future.delayed(Duration(seconds: 2));
          continue;
        } else {
          print('❌ GROQ request failed after $maxRetries attempts: $e');
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
      print('❌ Failed to parse JSON response: $e');
      print('Raw response: $completion');
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
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
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
          throw GroqException('API error: ${response.statusCode}', response.body);
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

class GroqException implements Exception {
  final String message;
  final String? responseBody;
  
  GroqException(this.message, [this.responseBody]);
  
  @override
  String toString() => 'GroqException: $message${responseBody != null ? '\nResponse: $responseBody' : ''}';
}

/// Factory methods for common use cases
class GroqClientFactory {
  /// Create client optimized for quest generation
  static GroqClient forQuestGeneration(String apiKey) {
    return GroqClient(apiKey, GroqClient.questGenerationModels);
  }

  /// Create client with default models
  static GroqClient withDefaults(String apiKey) {
    return GroqClient(apiKey, GroqClient.defaultModels);
  }

  /// Create client with custom models
  static GroqClient withModels(String apiKey, List<String> models) {
    return GroqClient(apiKey, models);
  }
}
