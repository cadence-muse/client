import 'package:http/http.dart' as http;

import 'http_client_factory_stub.dart'
    if (dart.library.js_interop) 'http_client_factory_web.dart'
    if (dart.library.io) 'http_client_factory_io.dart'
    as platform_client;

http.Client createHttpClient() => platform_client.createHttpClient();
