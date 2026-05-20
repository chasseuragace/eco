import 'dart:io';
import '../lib/novita_client.dart';

void main() async {
  final apiKey = Platform.environment['NOVITA_API_KEY'];

  if (apiKey == null || apiKey.isEmpty) {
    print('Error: NOVITA_API_KEY environment variable not set');
    return;
  }

  print('Testing Novita AI client...');

  // Create client with default models
  final client = NovitaClientFactory.withDefaults(apiKey);

  try {
    // Test basic completion
    final result = await client.generateCompletion(
      'Say hello in a friendly way!',
      temperature: 0.7,
      maxTokens: 50,
    );

    if (result != null) {
      print('✓ Basic completion successful:');
      print('Response: $result');
    } else {
      print('✗ Basic completion failed: returned null');
    }

    // Test JSON completion
    final jsonResult = await client.generateJsonCompletion(
      'Generate a simple JSON object with a greeting message and a number.',
      temperature: 0.8,
      maxTokens: 100,
    );

    if (jsonResult != null) {
      print('✓ JSON completion successful:');
      print('Response: $jsonResult');
    } else {
      print('✗ JSON completion failed: returned null');
    }

    // Test with conversation history
    final historyResult = await client.generateWithHistory(
      'What was my previous message?',
      [
        {'role': 'user', 'content': 'Hi, how are you?'},
        {
          'role': 'assistant',
          'content': 'I am doing well, thank you! How can I assist you today?'
        }
      ],
      temperature: 0.7,
      maxTokens: 100,
    );

    if (historyResult != null) {
      print('✓ Conversation history completion successful:');
      print('Response: $historyResult');
    } else {
      print('✗ Conversation history completion failed: returned null');
    }
  } catch (e) {
    print('✗ Error during testing: $e');
  } finally {
    client.dispose();
  }
}
