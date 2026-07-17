import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart';

void main() {
  test('Check Quill Config', () {
    final config = QuillSimpleToolbarConfig();
    print('showBoldButton: ${config.showBoldButton}');
    print('showItalicButton: ${config.showItalicButton}');
  });
}
