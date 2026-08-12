import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

/// The browser attaches the session cookie automatically once the backend
/// sets it via `Set-Cookie` on login — scripts can't read or set the
/// `Cookie` header themselves (it's a forbidden header per the Fetch spec).
/// `withCredentials` tells `fetch` to send/receive cookies on cross-origin
/// requests; the backend must answer with a specific
/// `Access-Control-Allow-Origin` (not `*`) and
/// `Access-Control-Allow-Credentials: true` for this to work.
http.Client createHttpClient() => BrowserClient()..withCredentials = true;
