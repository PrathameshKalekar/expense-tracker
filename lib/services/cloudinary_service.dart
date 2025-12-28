import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';

class CloudinaryService {
  // Cloudinary configuration
  static const String cloudName = 'dvak4smqy';
  static const String apiKey = '616729621421424';
  static const String apiSecret = 'EbRD9ionMFSnMFxbyROZR5qHZ6Y';

  // Compress image to reduce file size (aggressive compression for free plan)
  Future<File?> compressImage(File imageFile) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = path.join(
        tempDir.path,
        '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg',
      );

      // Aggressive compression: quality 40, max dimensions 800x800
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        quality: 40, // Lower quality for smaller file size
        minWidth: 800, // Max width
        minHeight: 800, // Max height
        format: CompressFormat.jpeg,
      );

      if (compressedFile != null) {
        return File(compressedFile.path);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Generate signature for Cloudinary upload
  String _generateSignature(Map<String, String> params) {
    // Sort parameters
    final sortedParams = params.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    // Create query string
    final queryString = sortedParams.map((e) => '${e.key}=${e.value}').join('&');

    // Add API secret
    final signatureString = '$queryString$apiSecret';

    // Generate SHA1 hash
    final bytes = utf8.encode(signatureString);
    final digest = sha1.convert(bytes);
    return digest.toString();
  }

  // Upload proof image to Cloudinary
  Future<String?> uploadProofImage(File imageFile, String expenseId) async {
    try {
      // Compress the image first
      final compressedFile = await compressImage(imageFile);
      if (compressedFile == null) {
        throw Exception('Failed to compress image');
      }

      // Generate unique public ID - use folder in public_id, not separate folder parameter
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final publicId = 'expense_tracker/expense_proofs/${expenseId}_$timestamp';

      // Prepare parameters for signature (only public_id and timestamp are signed)
      final timestampStr = timestamp.toString();
      final signatureParams = <String, String>{
        'public_id': publicId,
        'timestamp': timestampStr,
      };

      // Generate signature using only public_id and timestamp
      final signature = _generateSignature(signatureParams);

      // Prepare all upload parameters (signature params + additional params)
      final params = <String, String>{
        'public_id': publicId,
        'timestamp': timestampStr,
        'signature': signature,
        'api_key': apiKey,
        'quality': 'auto:low',
        'fetch_format': 'auto',
      };

      // Create multipart request
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri);

      // Add form fields
      params.forEach((key, value) {
        request.fields[key] = value;
      });

      // Add image file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          compressedFile.path,
        ),
      );

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final secureUrl = jsonResponse['secure_url'] as String?;
        return secureUrl;
      } else {
        throw Exception('Upload failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to upload image: ${e.toString()}');
    }
  }

  // Delete proof image from Cloudinary
  Future<void> deleteProofImage(String imageUrl) async {
    try {
      // Extract public_id from URL
      // Cloudinary URL format: https://res.cloudinary.com/{cloud_name}/image/upload/{version}/{public_id}.{format}
      // Or: https://res.cloudinary.com/{cloud_name}/image/upload/{public_id}.{format}
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;

      String? publicId;

      // Find the index of 'upload' in path segments
      final uploadIndex = pathSegments.indexOf('upload');
      if (uploadIndex >= 0 && uploadIndex < pathSegments.length - 1) {
        // Get public_id (everything after 'upload')
        final afterUpload = pathSegments.sublist(uploadIndex + 1);

        if (afterUpload.isNotEmpty) {
          // Join all segments after 'upload' and remove file extension
          var extractedPublicId = afterUpload.join('/');

          // Remove version prefix if present (v1234567890/)
          if (extractedPublicId.startsWith('v') && extractedPublicId.contains('/')) {
            final firstSlash = extractedPublicId.indexOf('/');
            if (firstSlash > 0 && RegExp(r'^v\d+$').hasMatch(extractedPublicId.substring(0, firstSlash))) {
              extractedPublicId = extractedPublicId.substring(firstSlash + 1);
            }
          }

          // Remove file extension
          final lastDot = extractedPublicId.lastIndexOf('.');
          if (lastDot > 0) {
            extractedPublicId = extractedPublicId.substring(0, lastDot);
          }
          publicId = extractedPublicId;
        } else {
          throw Exception('Unable to extract public_id from URL: No segments after upload');
        }
      } else {
        // Try alternative method: extract from path directly
        final path = uri.path;
        final uploadMatch = RegExp(r'/upload/(?:v\d+/)?(.+)').firstMatch(path);
        if (uploadMatch != null && uploadMatch.groupCount >= 1) {
          final group1 = uploadMatch.group(1);
          if (group1 != null && group1.isNotEmpty) {
            var extractedPublicId = group1;

            // Remove version prefix if present (v1234567890/)
            if (extractedPublicId.startsWith('v') && extractedPublicId.contains('/')) {
              final firstSlash = extractedPublicId.indexOf('/');
              if (firstSlash > 0 && RegExp(r'^v\d+$').hasMatch(extractedPublicId.substring(0, firstSlash))) {
                extractedPublicId = extractedPublicId.substring(firstSlash + 1);
              }
            }

            // Remove file extension
            final lastDot = extractedPublicId.lastIndexOf('.');
            if (lastDot > 0) {
              extractedPublicId = extractedPublicId.substring(0, lastDot);
            }
            publicId = extractedPublicId;
          } else {
            throw Exception('Unable to extract public_id from URL: No match group');
          }
        } else {
          throw Exception('Unable to extract public_id from URL: Invalid format');
        }
      }

      if (publicId.isEmpty) {
        throw Exception('Failed to extract public_id from URL');
      }

      // Prepare parameters for signed delete
      // Note: For signed requests, all parameters except api_key must be included in signature
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      // Parameters to include in signature (all except api_key)
      final signatureParams = <String, String>{
        'invalidate': 'true', // Invalidate CDN cache
        'public_id': publicId,
        'timestamp': timestamp,
      };

      // Generate signature (from invalidate, public_id, and timestamp)
      final signature = _generateSignature(signatureParams);

      // Build all parameters for the request
      final params = <String, String>{
        'invalidate': 'true',
        'public_id': publicId,
        'timestamp': timestamp,
        'signature': signature,
        'api_key': apiKey,
      };

      // Create delete request with form-encoded data in body
      final deleteUrl = 'https://api.cloudinary.com/v1_1/$cloudName/image/destroy';

      // Build form-encoded body
      final bodyFields = params.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');

      // Send POST request with form-encoded body
      final response = await http.post(
        Uri.parse(deleteUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: bodyFields,
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        // Check if result is 'ok' or 'not found'
        final result = jsonResponse['result'] as String?;
        if (result != 'ok' && result != 'not found') {
          // Image might have been already deleted or other issue, but don't throw error
        }
      } else {
        final errorBody = response.body;
        // Try to parse error message
        try {
          final errorJson = json.decode(errorBody);
          final errorMessage = errorJson['error']?['message'] ?? errorBody;
          throw Exception('Failed to delete image: ${response.statusCode} - $errorMessage');
        } catch (_) {
          throw Exception('Failed to delete image: ${response.statusCode} - $errorBody');
        }
      }
    } catch (e) {
      // Re-throw the exception so the caller knows deletion failed
      throw Exception('Failed to delete image from Cloudinary: ${e.toString()}');
    }
  }
}
