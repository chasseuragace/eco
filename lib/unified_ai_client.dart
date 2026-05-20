/// Unified AI Client with Groq Primary + Gemini Fallback
///
/// This client attempts to use Groq first, and automatically falls back
/// to Gemini when Groq fails or is unavailable.

import 'dart:convert';
import 'dart:io';
import 'groq_client.dart';
import 'gemini_client.dart';
import 'novita_client.dart';

class UnifiedAIClient {
  final GroqClient? groqClient;
  final GeminiClient? geminiClient;
  final NovitaClient? novitaClient;
  final bool preferGroq;
  final bool preferNovita;

  UnifiedAIClient({
    this.groqClient,
    this.geminiClient,
    this.novitaClient,
    this.preferGroq = true,
    this.preferNovita = false,
  }) {
    if (groqClient == null && geminiClient == null && novitaClient == null) {
      throw ArgumentError(
          'At least one client (Groq, Gemini, or Novita) must be provided');
    }
  }

  /// Factory method to create from environment variables (for development/testing)
  /// Note: Not recommended for production packages - use create() instead
  static UnifiedAIClient? fromEnvironment() {
    final groqKey = Platform.environment['GROQ_API_KEY'];
    final geminiKey = Platform.environment['GEMINI_API_KEY'];
    final novitaKey = Platform.environment['NOVITA_API_KEY'];

    GroqClient? groq;
    GeminiClient? gemini;
    NovitaClient? novita;

    if (groqKey != null && groqKey.isNotEmpty) {
      groq = GroqClientFactory.withDefaults(groqKey);
    }

    if (geminiKey != null && geminiKey.isNotEmpty) {
      gemini = GeminiClient(geminiKey);
    }

    if (novitaKey != null && novitaKey.isNotEmpty) {
      novita = NovitaClientFactory.withDefaults(novitaKey);
    }

    if (groq != null || gemini != null || novita != null) {
      return UnifiedAIClient(
        groqClient: groq,
        geminiClient: gemini,
        novitaClient: novita,
        preferGroq: true,
        preferNovita: novita != null && (groq == null || gemini == null),
      );
    }

    return null;
  }

  /// Factory method with explicit API keys
  static UnifiedAIClient create({
    String? groqApiKey,
    String? geminiApiKey,
    String? novitaApiKey,
    List<String>? groqModels,
    List<String>? novitaModels,
  }) {
    GroqClient? groq;
    GeminiClient? gemini;
    NovitaClient? novita;

    if (groqApiKey != null) {
      groq = groqModels != null
          ? GroqClient(groqApiKey, groqModels)
          : GroqClientFactory.withDefaults(groqApiKey);
    }

    if (geminiApiKey != null) {
      gemini = GeminiClient(geminiApiKey);
    }

    if (novitaApiKey != null) {
      novita = novitaModels != null
          ? NovitaClient(novitaApiKey, novitaModels)
          : NovitaClientFactory.withDefaults(novitaApiKey);
    }

    // Determine preferences - prioritize Novita if provided, then Groq, then Gemini
    final preferNovita = novita != null;
    final preferGroq = !preferNovita && groq != null;

    return UnifiedAIClient(
      groqClient: groq,
      geminiClient: gemini,
      novitaClient: novita,
      preferGroq: preferGroq,
      preferNovita: preferNovita,
    );
  }

  /// Generate completion with automatic fallback
  Future<String?> generateCompletion(
    String prompt, {
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 1500,
    List<Map<String, dynamic>>? tools,
    String? toolChoice,
  }) async {
    // Try Novita first if available and preferred
    if (preferNovita && novitaClient != null) {
      try {
        final result = await novitaClient!.generateCompletion(
          prompt,
          systemPrompt: systemPrompt,
          temperature: temperature,
          maxTokens: maxTokens,
          tools: tools,
          toolChoice: toolChoice,
        );

        if (result != null) {
          return result;
        }
      } catch (e) {
        // Fall back to Groq
      }
    }

    // Try Groq next if available and preferred
    if (preferGroq && groqClient != null) {
      try {
        final result = await groqClient!.generateCompletion(
          prompt,
          systemPrompt: systemPrompt,
          temperature: temperature,
          maxTokens: maxTokens,
          tools: tools,
          toolChoice: toolChoice,
        );

        if (result != null) {
          return result;
        }
      } catch (e) {
        // Fall back to Gemini
      }
    }

    // Fallback to Gemini
    if (geminiClient != null) {
      try {
        final result = await geminiClient!.generateCompletion(
          prompt,
          systemPrompt: systemPrompt,
          temperature: temperature,
          maxTokens: maxTokens,
        );

        if (result != null) {
          return result;
        }
      } catch (e) {
        // Silent error handling
      }
    }

    // If Novita wasn't preferred, try it as last resort
    if (!preferNovita && novitaClient != null) {
      try {
        final result = await novitaClient!.generateCompletion(
          prompt,
          systemPrompt: systemPrompt,
          temperature: temperature,
          maxTokens: maxTokens,
          tools: tools,
          toolChoice: toolChoice,
        );

        if (result != null) {
          return result;
        }
      } catch (e) {
        // Silent error handling
      }
    }

    // If Groq wasn't preferred, try it as last resort
    if (!preferGroq && groqClient != null) {
      try {
        final result = await groqClient!.generateCompletion(
          prompt,
          systemPrompt: systemPrompt,
          temperature: temperature,
          maxTokens: maxTokens,
          tools: tools,
          toolChoice: toolChoice,
        );

        if (result != null) {
          return result;
        }
      } catch (e) {
        // Silent error handling
      }
    }

    return null;
  }

  /// Generate JSON completion with fallback
  Future<Map<String, dynamic>?> generateJsonCompletion(
    String prompt, {
    String? systemPrompt,
    double temperature = 0.8,
    int maxTokens = 1500,
  }) async {
    // Try Groq first if available and preferred
    if (preferGroq && groqClient != null) {
      try {
        final result = await groqClient!.generateJsonCompletion(
          prompt,
          systemPrompt: systemPrompt,
          temperature: temperature,
          maxTokens: maxTokens,
        );

        if (result != null) {
          return result;
        }
      } catch (e) {
        // Fall back to Gemini
      }
    }

    // Fallback to Gemini with JSON parsing
    if (geminiClient != null) {
      try {
        final jsonSystemPrompt = (systemPrompt ?? '') +
            '\n\nIMPORTANT: Always respond with valid JSON only. Do not include markdown formatting or explanations.';

        final completion = await geminiClient!.generateCompletion(
          prompt,
          systemPrompt: jsonSystemPrompt,
          temperature: temperature,
          maxTokens: maxTokens,
        );

        if (completion != null) {
          try {
            // Clean up potential markdown formatting
            String jsonStr = completion.trim();
            if (jsonStr.startsWith('```json')) {
              jsonStr = jsonStr.substring(7);
            }
            if (jsonStr.endsWith('```')) {
              jsonStr = jsonStr.substring(0, jsonStr.length - 3);
            }

            final result = jsonDecode(jsonStr) as Map<String, dynamic>;
            return result;
          } catch (e) {
            // Failed to parse JSON
          }
        }
      } catch (e) {
        // Silent error handling
      }
    }

    return null;
  }

  /// Generate completion with conversation history and fallback
  Future<String?> generateWithHistory(
    String prompt,
    List<Map<String, String>> conversationHistory, {
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 1500,
  }) async {
    // Try Novita first if available and preferred
    if (preferNovita && novitaClient != null) {
      try {
        final result = await novitaClient!.generateWithHistory(
          prompt,
          conversationHistory,
          systemPrompt: systemPrompt,
          temperature: temperature,
          maxTokens: maxTokens,
        );

        if (result != null) {
          return result;
        }
      } catch (e) {
        // Fall back to Groq
      }
    }

    // Try Groq next if available and preferred
    if (preferGroq && groqClient != null) {
      try {
        final result = await groqClient!.generateWithHistory(
          prompt,
          conversationHistory,
          systemPrompt: systemPrompt,
          temperature: temperature,
          maxTokens: maxTokens,
        );

        if (result != null) {
          return result;
        }
      } catch (e) {
        // Fall back to Gemini
      }
    }

    // Fallback to Gemini (convert history to single prompt)
    if (geminiClient != null) {
      try {
        // Convert conversation history to a single prompt
        final historyPrompt = StringBuffer();
        if (systemPrompt != null) {
          historyPrompt.writeln('System: $systemPrompt\n');
        }

        for (final entry in conversationHistory) {
          final role = entry['role'] == 'assistant' ? 'Assistant' : 'User';
          historyPrompt.writeln('$role: ${entry['content']}\n');
        }

        historyPrompt.writeln('User: $prompt');

        final result = await geminiClient!.generateCompletion(
          historyPrompt.toString(),
          temperature: temperature,
          maxTokens: maxTokens,
        );

        if (result != null) {
          return result;
        }
      } catch (e) {
        // Silent error handling
      }
    }

    // If Novita wasn't preferred, try it as last resort
    if (!preferNovita && novitaClient != null) {
      try {
        final result = await novitaClient!.generateWithHistory(
          prompt,
          conversationHistory,
          systemPrompt: systemPrompt,
          temperature: temperature,
          maxTokens: maxTokens,
        );

        if (result != null) {
          return result;
        }
      } catch (e) {
        // Silent error handling
      }
    }

    // If Groq wasn't preferred, try it as last resort
    if (!preferGroq && groqClient != null) {
      try {
        final result = await groqClient!.generateWithHistory(
          prompt,
          conversationHistory,
          systemPrompt: systemPrompt,
          temperature: temperature,
          maxTokens: maxTokens,
        );

        if (result != null) {
          return result;
        }
      } catch (e) {
        // Silent error handling
      }
    }

    return null;
  }

  /// Call LLM with tools support and automatic fallback
  /// Returns a map compatible with the existing codebase pattern
  Future<Map<String, dynamic>> callLLMWithTools(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools, {
    double temperature = 0.7,
    int maxTokens = 1500,
  }) async {
    // For testing specific providers, use constructor parameters instead of env vars

    // Try Novita first if available and preferred
    if (preferNovita && novitaClient != null) {
      try {
        final result =
            await _tryNovitaWithTools(messages, tools, temperature, maxTokens);
        if (result['success'] == true) {
          return result;
        }
      } catch (e) {
        // Fall back to Groq
      }
    }

    // Try Groq next if available and preferred
    if (preferGroq && groqClient != null) {
      try {
        final result =
            await _tryGroqWithTools(messages, tools, temperature, maxTokens);
        if (result['success'] == true) {
          return result;
        }
      } catch (e) {
        // Fall back to Gemini
      }
    }

    // Fallback to Gemini
    if (geminiClient != null) {
      return await _tryGeminiWithTools(messages, tools, temperature, maxTokens);
    }

    // If Novita wasn't preferred, try it as last resort
    if (!preferNovita && novitaClient != null) {
      try {
        final result =
            await _tryNovitaWithTools(messages, tools, temperature, maxTokens);
        if (result['success'] == true) {
          return result;
        }
      } catch (e) {
        // Silent error handling
      }
    }

    // If Groq wasn't preferred, try it as last resort
    if (!preferGroq && groqClient != null) {
      try {
        final result =
            await _tryGroqWithTools(messages, tools, temperature, maxTokens);
        if (result['success'] == true) {
          return result;
        }
      } catch (e) {
        // Silent error handling
      }
    }

    return {
      'needsTools': false,
      'response': '',
      'success': false,
      'error': 'All LLM providers failed'
    };
  }

  /// Try Novita with tools (internal method)
  Future<Map<String, dynamic>> _tryNovitaWithTools(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools,
    double temperature,
    int maxTokens,
  ) async {
    if (novitaClient == null) {
      return {'success': false, 'error': 'Novita client not available'};
    }

    try {
      final response = await novitaClient!.httpClient.post(
        Uri.parse('https://api.novita.ai/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer ${novitaClient!.apiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': novitaClient!.currentModel,
          'messages': messages,
          'tools': tools,
          'tool_choice': 'auto',
          'temperature': temperature,
          'max_tokens': maxTokens,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _processToolResponse(data, success: true);
      } else {
        return {
          'success': false,
          'error': 'Novita API error: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Novita exception: $e'};
    }
  }

  /// Try Groq with tools (internal method)
  Future<Map<String, dynamic>> _tryGroqWithTools(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools,
    double temperature,
    int maxTokens,
  ) async {
    if (groqClient == null) {
      return {'success': false, 'error': 'Groq client not available'};
    }

    try {
      final response = await groqClient!.httpClient.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer ${groqClient!.apiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': groqClient!.currentModel,
          'messages': messages,
          'tools': tools,
          'tool_choice': 'auto',
          'temperature': temperature,
          'max_tokens': maxTokens,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _processToolResponse(data, success: true);
      } else {
        return {
          'success': false,
          'error': 'Groq API error: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Groq exception: $e'};
    }
  }

  /// Try Gemini with tools (internal method)
  Future<Map<String, dynamic>> _tryGeminiWithTools(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools,
    double temperature,
    int maxTokens,
  ) async {
    if (geminiClient == null) {
      return {
        'needsTools': false,
        'response': '',
        'success': false,
        'error': 'Gemini client not available'
      };
    }

    try {
      final geminiResponse = await geminiClient!.generateCompletionWithTools(
        messages,
        tools,
        temperature: temperature,
        maxTokens: maxTokens,
      );

      if (geminiResponse != null) {
        return _processToolResponse(geminiResponse, success: true);
      } else {
        return {
          'needsTools': false,
          'response': '',
          'success': false,
          'error': 'Gemini returned null'
        };
      }
    } catch (e) {
      return {
        'needsTools': false,
        'response': '',
        'success': false,
        'error': 'Gemini exception: $e'
      };
    }
  }

  /// Process tool response into the expected format
  Map<String, dynamic> _processToolResponse(Map<String, dynamic> data,
      {required bool success}) {
    if (!success) {
      return {'needsTools': false, 'response': '', 'success': false};
    }

    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      return {
        'needsTools': false,
        'response': '',
        'success': false,
        'error': 'No choices in response'
      };
    }

    final msg = choices[0]['message'];

    // Check for tool calls
    if (msg['tool_calls'] != null && (msg['tool_calls'] as List).isNotEmpty) {
      final toolCalls = msg['tool_calls'] as List;
      final toolsToCall = <String>[];
      final toolParams = <String, Map<String, dynamic>>{};

      for (final tc in toolCalls) {
        final name = tc['function']['name'] as String;
        final args = jsonDecode(tc['function']['arguments'] ?? '{}');
        toolsToCall.add(name);
        toolParams[name] = args;
      }

      return {
        'needsTools': true,
        'toolsToCall': toolsToCall,
        'toolParams': toolParams,
        'success': true,
      };
    }

    // No tools, return content
    return {
      'needsTools': false,
      'response': msg['content'] ?? '',
      'success': true,
    };
  }

  /// Get current status of all clients
  Map<String, dynamic> getStatus() {
    return {
      'groq_available': groqClient != null,
      'gemini_available': geminiClient != null,
      'novita_available': novitaClient != null,
      'prefer_groq': preferGroq,
      'prefer_novita': preferNovita,
      'groq_current_model': groqClient?.currentModel,
      'gemini_current_model': geminiClient?.currentModel,
      'novita_current_model': novitaClient?.currentModel,
    };
  }

  /// Switch preference between Groq and Gemini
  void setPreference({required bool preferGroq}) {
    // Note: This would require making preferGroq non-final
    // For now, create a new instance if you need different preferences
  }

  void dispose() {
    groqClient?.dispose();
    geminiClient?.dispose();
    novitaClient?.dispose();
  }
}

/// Exception for when all AI services fail
class AllAIServicesFailed implements Exception {
  final String message;
  final List<String> errors;

  AllAIServicesFailed(this.message, this.errors);

  @override
  String toString() =>
      'AllAIServicesFailed: $message\nErrors: ${errors.join(", ")}';
}
