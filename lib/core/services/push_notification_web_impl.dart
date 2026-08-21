import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS('window.MatrouhPush.isIosSafariNonStandalone')
external bool _isIosSafari();

@JS('window.MatrouhPush.getPermissionStatus')
external JSString _getPermStatus();

@JS('window.MatrouhPush.requestPermission')
external JSPromise<JSString> _requestPerm();

@JS('window.MatrouhPush.showBrowserNotification')
external bool _showBrowserNotif(JSString title, JSString body, JSString route);

bool isIosSafariNonStandaloneImpl() {
  try {
    return _isIosSafari();
  } catch (_) {
    return false;
  }
}

String getPermissionStatusImpl() {
  try {
    return _getPermStatus().toDart;
  } catch (_) {
    return 'unsupported';
  }
}

Future<String> requestPermissionImpl() async {
  try {
    final res = await _requestPerm().toDart;
    return res.toDart;
  } catch (_) {
    return 'denied';
  }
}

bool showBrowserNotificationImpl(String title, String body, String route) {
  try {
    return _showBrowserNotif(title.toJS, body.toJS, route.toJS);
  } catch (_) {
    return false;
  }
}
