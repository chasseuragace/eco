# Shared Ecosystem

A unified AI client library for Dart that provides seamless access to multiple AI providers with automatic fallback and load balancing.

## Features

- **Unified Interface**: Single API for multiple AI providers
- **Automatic Fallback**: Novita primary with Groq and Gemini fallback
- **Load Balancing**: Round-robin model rotation
- **Tool Support**: Function calling capabilities
- **Conversation History**: Multi-turn conversation support
- **JSON Generation**: Structured output generation

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  shared_ecosystem: ^1.0.0
```

## Quick Start

```dart
import 'package:shared_ecosystem/shared_ecosystem.dart';

void main() async {
  // Create client with your API keys
  final client = UnifiedAIClient.create(
    novitaApiKey: 'your-novita-api-key',
    groqApiKey: 'your-groq-api-key',
    geminiApiKey: 'your-gemini-api-key',
  );

  // Generate completion with automatic fallback
  final response = await client.generateCompletion(
    'Write a haiku about programming',
    systemPrompt: 'You are a creative poet.',
    temperature: 0.8,
  );

  print(response);
  client.dispose();
}
```

## API Keys

You need API keys from one or more providers:

- **Novita**: Get your key from [novita.ai](https://novita.ai) (set as NOVITA_AUTH_TOKEN)
- **Groq**: Get your key from [console.groq.com](https://console.groq.com)
- **Gemini**: Get your key from [Google AI Studio](https://makersuite.google.com/app/apikey)

## Usage Examples

### Basic Completion

```dart
final client = UnifiedAIClient.create(
  novitaApiKey: 'your-novita-key',
  groqApiKey: 'your-groq-key',
  geminiApiKey: 'your-gemini-key',
);

final response = await client.generateCompletion(
  'Explain quantum computing in simple terms',
  temperature: 0.7,
  maxTokens: 500,
);
```

### JSON Generation

```dart
final jsonResponse = await client.generateJsonCompletion(
  'Create a user profile object with name, age, and interests',
  systemPrompt: 'Generate valid JSON only.',
);
```

### With Conversation History

```dart
final response = await client.generateWithHistory(
  'What should I learn next?',
  [
    {'role': 'user', 'content': 'I know Python basics'},
    {'role': 'assistant', 'content': 'Great! Python is versatile.'},
  ],
);
```

### Tool/Function Calling

```dart
final tools = [
  {
    'type': 'function',
    'function': {
      'name': 'get_weather',
      'description': 'Get weather for a location',
      'parameters': {
        'type': 'object',
        'properties': {
          'location': {'type': 'string'},
        },
        'required': ['location']
      }
    }
  }
];

final result = await client.callLLMWithTools(messages, tools);
if (result['needsTools'] == true) {
  // Execute the requested tools
  final toolsToCall = result['toolsToCall'] as List<String>;
  // ... handle tool execution
}
```

## Configuration Options

### Single Provider

```dart
// Novita only
final novitaClient = UnifiedAIClient.create(novitaApiKey: 'your-key');

// Groq only  
final groqClient = UnifiedAIClient.create(groqApiKey: 'your-key');

// Gemini only  
final geminiClient = UnifiedAIClient.create(geminiApiKey: 'your-key');
```

### Custom Models

```dart
final client = UnifiedAIClient.create(
  novitaApiKey: 'your-novita-key',
  novitaModels: ['deepseek/deepseek-v4-pro', 'qwen/qwen3.5-27b'],
  groqApiKey: 'your-groq-key',
  groqModels: ['llama-3.3-70b-versatile', 'mixtral-8x7b-32768'],
);
```

### Preference Control

```dart
// Prefer Novita over Groq and Gemini
final client = UnifiedAIClient(
  novitaClient: NovitaClient('novita-key', NovitaClient.defaultModels),
  groqClient: GroqClient('groq-key', GroqClient.defaultModels),
  geminiClient: GeminiClient('gemini-key'),
  preferNovita: true, // Use Novita first
);

// Prefer Gemini over Groq
final client = UnifiedAIClient(
  groqClient: GroqClient('groq-key', GroqClient.defaultModels),
  geminiClient: GeminiClient('gemini-key'),
  preferGroq: false, // Use Gemini first
);
```

## Error Handling

The client automatically handles:
- Rate limiting with exponential backoff
- Model rotation on failures
- Provider fallback
- Network timeouts

```dart
try {
  final response = await client.generateCompletion('Hello');
  if (response != null) {
    print('Success: $response');
  } else {
    print('All providers failed');
  }
} catch (e) {
  print('Error: $e');
}
```

## License

MIT License - see LICENSE file for details.