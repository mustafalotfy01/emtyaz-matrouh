// Non-web fallback stub for VM and tests

bool isIosSafariNonStandaloneImpl() => false;

String getPermissionStatusImpl() => 'unsupported';

Future<String> requestPermissionImpl() async => 'denied';

bool showBrowserNotificationImpl(String title, String body, String route) => false;
