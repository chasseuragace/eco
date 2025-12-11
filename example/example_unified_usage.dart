/// Example usage of UnifiedAIClient with Groq primary + Gemini fallback
import 'package:shared_ecosystem/shared_ecosystem.dart';

void main() async {
  // RECOMMENDED: Create with explicit API keys
  final client = UnifiedAIClient.create(
    groqApiKey: 'your-groq-api-key-here',
    geminiApiKey: 'your-gemini-api-key-here',
  );

  // Alternative: Create with only one provider
  // final client = UnifiedAIClient.create(
  //   groqApiKey: 'your-groq-key',
  //   // geminiApiKey: null, // Will use Groq only
  // );

  // For development/testing only (not recommended for packages):
  // final client = UnifiedAIClient.fromEnvironment();

  print('Client status: ${client.getStatus()}');

  // Test basic completion with automatic fallback
  try {
    final response = await client.generateCompletion(
      'Write a short poem about coding',
      systemPrompt: 'You are a creative assistant that writes concise, meaningful poetry.',
      temperature: 0.8,
    );

    if (response != null) {
      print('✅ Success! Response:\n$response');
    } else {
      print('❌ All services failed');
    }
  } catch (e) {
    print('❌ Error: $e');
  }

  // Test JSON completion
  try {
    final jsonResponse = await client.generateJsonCompletion(
      'Create a simple quest object with title, description, and difficulty level',
      systemPrompt: 'Generate valid JSON for a game quest.',
    );

    if (jsonResponse != null) {
      print('✅ JSON Success: $jsonResponse');
    } else {
      print('❌ JSON generation failed');
    }
  } catch (e) {
    print('❌ JSON Error: $e');
  }

  // Test with conversation history
  try {
    final historyResponse = await client.generateWithHistory(
      'What should I do next?',
      [
        {'role': 'user', 'content': 'I am learning Dart programming'},
        {'role': 'assistant', 'content': 'That\'s great! Dart is excellent for Flutter development.'},
        {'role': 'user', 'content': 'I want to build a mobile app'},
      ],
      systemPrompt: 'You are a helpful programming mentor.',
    );

    if (historyResponse != null) {
      print('✅ History Success: $historyResponse');
    } else {
      print('❌ History generation failed');
    }
  } catch (e) {
    print('❌ History Error: $e');
  }

  client.dispose();
}