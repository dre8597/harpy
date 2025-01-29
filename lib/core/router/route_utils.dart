import 'package:go_router/go_router.dart';

/// Whether a given location has a matching route.
bool locationHasRouteMatch({
  required String location,
  required List<RouteBase> routes,
}) {
  final uri = Uri.parse(location);
  return _hasMatchingRoute(uri.path, routes);
}

bool _hasMatchingRoute(String path, List<RouteBase> routes) {
  for (final route in routes) {
    if (route is! GoRoute) continue;
    if (_pathMatches(route.path, path)) {
      return true;
    }
    if (route.routes.isNotEmpty) {
      final subPath = _getSubPath(path, route.path);
      if (subPath != null && _hasMatchingRoute(subPath, route.routes)) {
        return true;
      }
    }
  }
  return false;
}

bool _pathMatches(String routePath, String path) {
  final routeParts = routePath.split('/');
  final pathParts = path.split('/');

  if (routeParts.length > pathParts.length) return false;

  for (var i = 0; i < routeParts.length; i++) {
    if (routeParts[i].startsWith(':')) continue; // Parameter matches anything
    if (routeParts[i] != pathParts[i]) return false;
  }
  return true;
}

String? _getSubPath(String path, String parentPath) {
  if (!path.startsWith(parentPath)) return null;
  if (path.length == parentPath.length) return null;
  return path.substring(parentPath.length);
}
