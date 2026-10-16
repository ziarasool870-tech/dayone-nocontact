/// One-tap "Add widget to Home screen" via Android's pin-widget request.
///
/// Uses [HomeWidget.requestPinWidget] (AppWidgetManager.requestPinAppWidget,
/// Android 8+). Returns true when the system placement dialog was shown.
/// Returns false when pinning isn't supported (old Android / launcher) or
/// the request threw — callers should then show the manual steps instead.
library;

import 'package:home_widget/home_widget.dart';

/// Test seam: lets widget tests stub the platform outcome.
typedef PinSupportCheck = Future<bool?> Function();
typedef PinRequestCall = Future<void> Function();

class WidgetPinService {
  WidgetPinService({
    PinSupportCheck? supportCheck,
    PinRequestCall? requestCall,
  })  : _supportCheck = supportCheck ?? HomeWidget.isRequestPinWidgetSupported,
        _requestCall = requestCall ??
            (() => HomeWidget.requestPinWidget(
                  qualifiedAndroidName:
                      'com.dayone.nocontact.DayOneWidgetProvider',
                ));

  final PinSupportCheck _supportCheck;
  final PinRequestCall _requestCall;

  Future<bool> requestPin() async {
    try {
      final supported = await _supportCheck();
      if (supported != true) return false;
      await _requestCall();
      return true;
    } catch (_) {
      return false;
    }
  }
}
