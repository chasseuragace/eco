import 'dart:io';
import 'lib/unified_ai_client.dart';
import 'lib/novita_client.dart';

void main() async {
  final apiKey = Platform.environment['NOVITA_AUTH_TOKEN'];
  
  print('Testing Unified AI Client with Novita AI integration...');
  
  // Test 1: Create client with Novita API key (even if invalid)
  final clientWithNovita = UnifiedAIClient.create(
    novitaApiKey: apiKey ?? 'test_key',
  );
  
  final status = clientWithNovita.getStatus();
  print('\n=== Test 1: Client Creation ===');
  print('Novita available: ${status['novita_available']}');
  print('Prefer Novita: ${status['prefer_novita']}');
  print('Current Novita model: ${status['novita_current_model']}');
  
  // Test 2: Create client with multiple providers
  final multiClient = UnifiedAIClient.create(
    novitaApiKey: apiKey ?? 'test_key',
    groqApiKey: Platform.environment['GROQ_API_KEY'],
    geminiApiKey: Platform.environment['GEMINI_API_KEY'],
  );
  
  final multiStatus = multiClient.getStatus();
  print('\n=== Test 2: Multi-Provider Client ===');
  print('Novita available: ${multiStatus['novita_available']}');
  print('Groq available: ${multiStatus['groq_available']}');
  print('Gemini available: ${multiStatus['gemini_available']}');
  print('Prefer Novita: ${multiStatus['prefer_novita']}');
  print('Prefer Groq: ${multiStatus['prefer_groq']}');
  
  // Test 3: Test fromEnvironment method
  print('\n=== Test 3: Environment Factory ===');
  final envClient = UnifiedAIClient.fromEnvironment();
  if (envClient != null) {
    final envStatus = envClient.getStatus();
    print('Novita from env: ${envStatus['novita_available']}');
    print('Groq from env: ${envStatus['groq_available']}');
    print('Gemini from env: ${envStatus['gemini_available']}');
  } else {
    print('No clients created from environment (expected if no API keys set)');
  }
  
  // Test 4: Show that Novita models are accessible
  print('\n=== Test 4: Novita Model Lists ===');
  print('Default models: ${NovitaClient.defaultModels}');
  print('Quest generation models: ${NovitaClient.questGenerationModels}');
  
  clientWithNovita.dispose();
  multiClient.dispose();
  envClient?.dispose();
  
  print('\n=== All tests completed ===');
}