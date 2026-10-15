// brand.dart
// The company the signed-in user is working for: Vehga or Pronto Moto.
// Mirrors prontofirebase's src/app/services/brand.service.ts — keep in sync.
//
// The backend scopes by the X-Brand header: it decides which company a new case
// is stamped with and which company's cases a listing returns. A request without
// it is unscoped, so before this the app saw both companies' cases mixed together
// and every case it created was filed under Vehga.

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum BrandKey { vehga, pronto }

class BrandProfile {
  final BrandKey key;

  /// Shown in the picker and the app bars.
  final String name;

  /// Legal entity, for the login footer and anywhere the full name is needed.
  final String legalName;

  /// Horizontal lockup that spells the company name, the same mark the report prints.
  final String logoAsset;

  /// The portal's --brand colour for this company.
  final Color color;

  const BrandProfile({
    required this.key,
    required this.name,
    required this.legalName,
    required this.logoAsset,
    required this.color,
  });

  /// The value the backend expects in X-Brand.
  String get header => key.name;
}

const Map<BrandKey, BrandProfile> brands = {
  BrandKey.vehga: BrandProfile(
    key: BrandKey.vehga,
    name: 'Vehga',
    legalName: 'Vehga Inspections Private Limited',
    logoAsset: 'assets/vehga-logo-trimmed.png',
    color: Color(0xFF037076),
  ),
  BrandKey.pronto: BrandProfile(
    key: BrandKey.pronto,
    name: 'Pronto Moto',
    legalName: 'Pronto Moto Services',
    logoAsset: 'assets/pronto-logo-trimmed.png',
    // Darkened from the logo's #02944E for contrast on white, as in the portal.
    color: Color(0xFF02763E),
  ),
};

/// Display name for a brand that came from the backend rather than from the
/// picker, such as a dedupe match, which can belong to either company. Null,
/// blank and unrecognised all mean Vehga, matching BrandContext.Normalise on the
/// server: cases written before multi-brand carry no brand at all.
String brandName(String? raw) {
  final v = (raw ?? '').trim().toLowerCase();
  return (v == 'pronto' ? brands[BrandKey.pronto]! : brands[BrandKey.vehga]!).name;
}

class Brand {
  static const _storageKey = 'active_brand';

  /// Listened to by the app's theme, so choosing a company repaints the login
  /// screen at once and it is obvious which one you are signing into.
  static final ValueNotifier<BrandKey> active = ValueNotifier(BrandKey.vehga);

  static BrandProfile get profile => brands[active.value]!;

  /// Restores the last choice. Vehga when nothing was chosen yet.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);
    active.value = BrandKey.values.firstWhere((b) => b.name == stored,
        orElse: () => BrandKey.vehga);
  }

  /// Called by the login picker.
  static Future<void> select(BrandKey key) async {
    active.value = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, key.name);
  }
}

/// Adds X-Brand to every request, as the portal's auth interceptor does.
class _BrandedClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['X-Brand'] = Brand.profile.header;
    return _inner.send(request);
  }
}

/// The client every backend call goes through. Use it instead of the http
/// package's top-level get/post/put, which would leave the company out.
final http.Client apiHttp = _BrandedClient();
