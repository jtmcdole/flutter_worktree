import 'dart:convert';
import 'dart:io';

void hydrate(String coreFile, String templateFile, String outputFile) {
  print('Processing $coreFile -> $outputFile...');

  final coreFileObj = File(coreFile);
  if (!coreFileObj.existsSync()) {
    print('Error: $coreFile not found');
    exit(1);
  }
  
  // Read core logic as string and normalize line endings to LF (\n)
  final coreContent = coreFileObj.readAsStringSync().replaceAll('\r\n', '\n');
  
  // Encode payload to base64
  final payload = base64Encode(utf8.encode(coreContent));
  
  final templateFileObj = File(templateFile);
  if (!templateFileObj.existsSync()) {
    print('Error: $templateFile not found');
    exit(1);
  }

  // Read template as string (assuming UTF-8)
  // We use readAsString to easily do string replacement, 
  // ensuring we handle the template text correctly.
  // Note: Binary replacement would be safer for unknown encodings, 
  // but source files are likely UTF-8 text.
  String templateContent = templateFileObj.readAsStringSync();
  
  if (!templateContent.contains('REPLACE_ME')) {
    print('Error: REPLACE_ME not found in $templateFile');
    exit(1);
  }

  final newContent = templateContent.replaceFirst('REPLACE_ME', payload);
  
  final outputFileObj = File(outputFile);
  outputFileObj.writeAsStringSync(newContent);
  
  print('Written to $outputFile');
}

void main() {
  final distDir = Directory('dist');
  if (!distDir.existsSync()) {
    distDir.createSync();
  }

  // Bash
  hydrate('core_logic.sh', 'setup_flutter.template.sh', 'dist/setup_flutter.sh');
  
  // PowerShell
  hydrate('core_logic.ps1', 'setup_flutter.template.ps1', 'dist/setup_flutter.ps1');
}
