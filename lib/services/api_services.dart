import 'dart:convert';
import 'dart:io';
import 'package:artist/Global/global.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

/// Délai maximal d'une requête simple (GET/POST/DELETE). Sans lui, une
/// connexion qui ne répond jamais laissait le loader tourner indéfiniment.
const Duration apiTimeout = Duration(seconds: 15);

/// Délai des envois de fichiers (photos, vidéos).
const Duration apiUploadTimeout = Duration(seconds: 300);

/// Réponse « réseau » au même format que les erreurs serveur
/// (`error {json}`) : tous les appelants la traitent déjà via
/// `value.split(' ').first != 'error'` et [parseError] affiche le message.
/// Avant, une coupure réseau levait une exception non gérée -> loader
/// infini.
String networkErrorResponse(Object e) {
  myPrint(e);
  return 'error ${jsonEncode({
        'status': 'error',
        'code': 'network',
        'message': 'msg_network_error'.tr,
      })}';
}

abstract class ApiService {
  Future hitAPI();
  Future hitMultipartAPI(String file);
  Future hitMultiImagesAPI(List file, String? imageKey);
}

class ApiResponse extends ApiService {
  String? type;
  String? _url;
  Map<String, String>? _body;
  Map? _body2;
  Map<String, String>? headers;

  set urlSetter(String url) {
    _url = url;
  }

  set bodySetter(Map<String, String>? body) {
    _body = body;
    _body2 = null;
    headers = null;
  }

  set bodySetter2(Map body) {
    _body2 = body;
    _body = null;
  }

  set typeSetter(String type) {
    this.type = type;
  }

  set headerSetter(Map<String, String> headers) {
    this.headers = headers;
  }

  Map<String, String> _getHeaders() {
    Map<String, String> currentHeaders = headers ?? {};
    if (authorization.isNotEmpty || userModel.value.token != null) {
      currentHeaders['Authorization'] =
          'Bearer ${userModel.value.token ?? authorization}';
    }
    return currentHeaders;
  }

  @override
  Future hitAPI() async {
    final finalHeaders = _getHeaders();
    try {
      if (type == 'get') {
        final response = await http
            .get(Uri.parse(_url!), headers: finalHeaders)
            .timeout(apiTimeout);
        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = response.body;
          return data;
        } else {
          myPrint('HTTP ${response.statusCode} $_url -> ${response.body}');
          return "error ${response.body}";
        }
      } else if (type == 'delete') {
        final response = await http
            .delete(Uri.parse(_url!), headers: finalHeaders)
            .timeout(apiTimeout);
        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = response.body;
          return data;
        } else {
          myPrint('HTTP ${response.statusCode} $_url -> ${response.body}');
          return "error ${response.body}";
        }
      } else if (type == 'post') {
        final response = await http
            .post(
              Uri.parse(_url!),
              headers: finalHeaders,
              body: _body ?? jsonEncode(_body2),
            )
            .timeout(apiTimeout);
        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = response.body;
          return data;
        } else {
          myPrint('HTTP ${response.statusCode} $_url -> ${response.body}');
          return "error ${response.body}";
        }
      } else if (type == 'put') {
        // Même contrat que 'post' (form-urlencoded via _body, JSON via
        // _body2). Utilisé par PUT /events/:id/guests.
        final response = await http
            .put(
              Uri.parse(_url!),
              headers: finalHeaders,
              body: _body ?? jsonEncode(_body2),
            )
            .timeout(apiTimeout);
        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = response.body;
          return data;
        } else {
          myPrint('HTTP ${response.statusCode} $_url -> ${response.body}');
          return "error ${response.body}";
        }
      }
      return networkErrorResponse('hitAPI: type de requête inconnu "$type"');
    } catch (e) {
      return networkErrorResponse(e);
    }
  }

  @override
  Future hitMultipartAPI(
    file, {
    String? key,
    String? pic2,
    String? key2,
  }) async {
    final finalHeaders = _getHeaders();
    try {
      var request = http.MultipartRequest('$type', Uri.parse('$_url'));
      request.fields.addAll(_body ?? {});
      request.headers.addAll(finalHeaders);
      file.isEmpty
          ? null
          : request.files.add(
              await http.MultipartFile.fromPath(key ?? 'profile_picture', file),
            );
      (pic2 ?? '').isEmpty
          ? null
          : request.files.add(
              await http.MultipartFile.fromPath(
                key2 ?? 'profile_picture',
                pic2!,
              ),
            );
      http.StreamedResponse value = await request.send().timeout(
        apiUploadTimeout,
      );
      final response = await http.Response.fromStream(value);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.body;
        return data;
      } else {
        myPrint('HTTP ${response.statusCode} $_url -> ${response.body}');
        return "error ${response.body}";
      }
    } catch (e) {
      return networkErrorResponse(e);
    }
  }

  @override
  Future hitMultiImagesAPI(List file, [String? imageKey]) async {
    final finalHeaders = _getHeaders();
    try {
      var request = http.MultipartRequest('$type', Uri.parse('$_url'));
      request.fields.addAll(_body ?? {});
      request.headers.addAll(finalHeaders);

      if (file.isNotEmpty) {
        for (File value in file) {
          request.files.add(
            await http.MultipartFile.fromPath(
              imageKey ?? 'images[]',
              value.path,
            ),
          );
        }
      }

      http.StreamedResponse value = await request.send().timeout(
        apiUploadTimeout,
      );
      final response = await http.Response.fromStream(value);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.body;
        return data;
      } else {
        myPrint('HTTP ${response.statusCode} $_url -> ${response.body}');
        return "error ${response.body}";
      }
    } catch (e) {
      return networkErrorResponse(e);
    }
  }
}
