/// Example usage of UnifiedAIClient with tools support
import 'package:shared_ecosystem/shared_ecosystem.dart';

void main() async {
  // Create client with your API keys
  final client = UnifiedAIClient.create(
    groqApiKey: 'your-groq-api-key-here',
    geminiApiKey: 'your-gemini-api-key-here',
  );

  // Example messages and tools (same format as your existing code)
  final messages = [
    {
      'role': 'system',
      'content': 'You are a helpful assistant that can call functions to help users.'
    },
    {
      'role': 'user', 
      'content': 'What\'s the weather like in San Francisco?'
    }
  ];

  final tools = [
    {
      'type': 'function',
      'function': {
        'name': 'get_weather',
        'description': 'Get current weather for a location',
        'parameters': {
          'type': 'object',
          'properties': {
            'location': {
              'type': 'string',
              'description': 'The city and state, e.g. San Francisco, CA'
            },
            'unit': {
              'type': 'string',
              'enum': ['celsius', 'fahrenheit'],
              'description': 'Temperature unit'
            }
          },
          'required': ['location']
        }
      }
    }
  ];

  try {
    // This replaces your _callLLMWithTools method
    final result = await client.callLLMWithTools(messages, tools);

    if (result['success'] == true) {
      if (result['needsTools'] == true) {
        print('🔧 Tools needed:');
        print('Tools to call: ${result['toolsToCall']}');
        print('Tool params: ${result['toolParams']}');
        
        // Here you would execute the actual tools and continue the conversation
        // For example:
        final toolsToCall = result['toolsToCall'] as List<String>;
        final toolParams = result['toolParams'] as Map<String, Map<String, dynamic>>;
        
        for (final toolName in toolsToCall) {
          final params = toolParams[toolName]!;
          print('Would call $toolName with params: $params');
          
          // Execute your actual tool here
          // final toolResult = await executeYourTool(toolName, params);
        }
      } else {
        print('✅ Direct response: ${result['response']}');
      }
    } else {
      print('❌ Failed: ${result['error']}');
    }
  } catch (e) {
    print('❌ Exception: $e');
  }

  client.dispose();
}

// Example: Test with specific providers
void testSpecificProviders() async {
  // Test with Groq only
  final groqOnlyClient = UnifiedAIClient.create(
    groqApiKey: 'your-groq-key',
    // No Gemini key = Groq only
  );

  // Test with Gemini only
  final geminiOnlyClient = UnifiedAIClient.create(
    geminiApiKey: 'your-gemini-key',
    // No Groq key = Gemini only
  );

  // Test with Gemini preferred
  final geminiPreferredClient = UnifiedAIClient(
    groqClient: GroqClient('groq-key', GroqClient.defaultModels),
    geminiClient: GeminiClient('gemini-key'),
    preferGroq: false, // Use Gemini first
  );

  print('Created clients for testing different provider configurations');
}

// Complete example with tool execution simulation
void completeToolsExample() async {
  final client = UnifiedAIClient.create(
    groqApiKey: 'your-groq-key',
    geminiApiKey: 'your-gemini-key',
  );

  final messages = [
    {
      'role': 'system',
      'content': 'You are a helpful assistant with access to weather and calculation tools.'
    },
    {
      'role': 'user',
      'content': 'What\'s the weather in Tokyo and what\'s 15 + 27?'
    }
  ];

  final tools = [
    {
      'type': 'function',
      'function': {
        'name': 'get_weather',
        'description': 'Get current weather for a location',
        'parameters': {
          'type': 'object',
          'properties': {
            'location': {'type': 'string', 'description': 'City name'},
          },
          'required': ['location']
        }
      }
    },
    {
      'type': 'function',
      'function': {
        'name': 'calculate',
        'description': 'Perform mathematical calculations',
        'parameters': {
          'type': 'object',
          'properties': {
            'expression': {'type': 'string', 'description': 'Math expression to evaluate'},
          },
          'required': ['expression']
        }
      }
    }
  ];

  try {
    final result = await client.callLLMWithTools(messages, tools);

    if (result['success'] == true) {
      if (result['needsTools'] == true) {
        print('🔧 AI wants to call tools:');
        
        final toolsToCall = result['toolsToCall'] as List<String>;
        final toolParams = result['toolParams'] as Map<String, Map<String, dynamic>>;
        
        // Simulate tool execution
        final toolResults = <String, String>{};
        
        for (final toolName in toolsToCall) {
          final params = toolParams[toolName]!;
          print('Calling $toolName with: $params');
          
          // Simulate tool execution
          String toolResult;
          switch (toolName) {
            case 'get_weather':
              toolResult = 'Weather in ${params['location']}: 22°C, sunny';
              break;
            case 'calculate':
              toolResult = 'Result: 42'; // Simulated calculation
              break;
            default:
              toolResult = 'Tool executed successfully';
          }
          
          toolResults[toolName] = toolResult;
          print('Tool result: $toolResult');
        }
        
        // Continue conversation with tool results
        final followUpMessages = [
          ...messages,
          {
            'role': 'assistant',
            'content': 'I need to call some tools to help you.',
            'tool_calls': result['toolsToCall'], // Include original tool calls
          },
          // Add tool results as separate messages
          for (final entry in toolResults.entries)
            {
              'role': 'tool',
              'name': entry.key,
              'content': entry.value,
            },
        ];
        
        // Get final response
        final finalResult = await client.generateCompletion(
          'Please provide a summary based on the tool results.',
          // Could also use generateWithHistory with the full conversation
        );
        
        print('🎯 Final AI response: $finalResult');
        
      } else {
        print('✅ Direct response (no tools needed): ${result['response']}');
      }
    } else {
      print('❌ Failed: ${result['error']}');
    }
  } catch (e) {
    print('❌ Exception: $e');
  }

  client.dispose();
}