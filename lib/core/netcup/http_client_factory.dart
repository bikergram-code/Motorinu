import 'package:http/http.dart' as http;

import 'http_client_stub.dart'
    if (dart.library.io) 'http_client_io.dart';

http.Client createBikernameHttpClient(String baseUrl) => createHttpClient(baseUrl);
