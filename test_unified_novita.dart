import 'dart:io';
import 'lib/unified_ai_client.dart';

void main() async {
  final apiKey = Platform.environment['NOVITA_AUTH_TOKEN'];
  
  if (apiKey == null || apiKey.isEmpty) {
    print('Error: NOVITA_AUTH_TOKEN environment variable not set');
    return;
  }
  
  print('Testing Unified AI Client with Novita AI...');
  
  // Create unified client with Novita API key
  final client = UnifiedAIClient.create(
    novitaApiKey: apiKey,
  );
  
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
    
    // Check status
    final status = client.getStatus();
    print('\nClient Status:');
    print('Novita available: ${status['novita_available']}');
    print('Prefer Novita: ${status['prefer_novita']}');
    print('Current Novita model: ${status['novita_current_model']}');
    
  } catch (e) {
    print('✗ Error during testing: $e');
  } finally {
    client.dispose();
  }
}