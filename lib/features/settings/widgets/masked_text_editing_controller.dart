import 'package:flutter/widgets.dart';

class MaskedTextEditingController extends TextEditingController {
  MaskedTextEditingController({super.text, bool masked = true})
    : _masked = masked;

  bool _masked;

  bool get masked => _masked;

  set masked(bool value) {
    if (_masked == value) {
      return;
    }
    _masked = value;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (!_masked) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    return TextSpan(
      style: style,
      text: List.filled(text.runes.length, '•').join(),
    );
  }
}
