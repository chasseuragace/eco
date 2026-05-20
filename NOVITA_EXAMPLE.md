# Novita AI Client Example

This example demonstrates how to use the Novita AI client directly or through the unified AI client.

## Direct Novita Client Usage

```dart
import 'package:shared_ecosystem/lib/novita_client.dart';

void main() async {
  // Create Novita client with API key from environment
  final apiKey = Platform.environment['NOVITA_AUTH_TOKEN'];
  final client = NovitaClientFactory.withDefaults(apiKey!);
  
  try {
    // Simple completion
    final response = await client.generateCompletion(
      'What is the capital of France?',
      temperature: 0.7,
      maxTokens: 100,
    );
    
    print('Response: $response');
    
    // JSON completion
    final jsonResponse = await client.generateJsonCompletion(
      'Generate a JSON object with a person\'s name and age',
      temperature: 0.8,
      maxTokens: 150,
    );
    
    print('JSON Response: $jsonResponse');
  } finally {
    client.dispose();
  }
}
```

## Unified AI Client with Novita

```dart
import 'package:shared_ecosystem/lib/unified_ai_client.dart';

void main() async {
  // Create unified client preferring Novita
  final client = UnifiedAIClient.create(
    novitaApiKey: Platform.environment['NOVITA_AUTH_TOKEN'],
    groqApiKey: Platform.environment['GROQ_API_KEY'], 
    geminiApiKey: Platform.environment['GEMINI_API_KEY'],
    // Optional: specify custom models for each provider
    novitaModels: ['deepseek/deepseek-v4-pro', 'qwen/qwen3.5-27b'],
    groqModels: ['llama-3.3-70b-versatile', 'mixtral-8x7b-32768'],
  );
  
  try {
    // This will try Novita first, then fall back to Groq, then Gemini
    final response = await client.generateCompletion(
      'Write a short story about a robot learning to paint',
      systemPrompt: 'You are a creative storyteller.',
      temperature: 0.8,
      maxTokens: 300,
    );
    
    print('Unified AI Response: $response');
    
    // Check which provider is being used
    final status = client.getStatus();
    print('Current Novita model: ${status['novita_current_model']}');
    print('Prefer Novita: ${status['prefer_novita']}');
  } finally {
    client.dispose();
  }
}
```

## Model Information

Novita AI provides access to various models including:

- **DeepSeek V4 Pro**: Flagship model with excellent reasoning and coding capabilities
- **DeepSeek V4 Flash**: Faster, cost-effective variant
- **Qwen 3.5**: Strong performance across multiple benchmarks
- **Kimi K2.6**: Moonshot AI's latest offering

The client uses round-robin load balancing across the specified models for optimal performance.