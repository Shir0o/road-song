import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/trip_models.dart';
import 'remote_trip_store.dart';

/// Surfaces a trip's shareable link: the native share sheet on mobile (and
/// the Web Share API in browsers that support it), clipboard everywhere.
/// The link shape is `roadsong.app/t/<tripCode>` per the spec.
class TripLinkSharer {
  const TripLinkSharer();

  /// The shareable link for [trip]. Falls back to the trip's stored
  /// [Trip.sessionLink] when it has no code-shaped link.
  String linkFor(Trip trip) {
    final String? code = tripCodeFromLink(trip.sessionLink);
    if (code != null) return buildTripLink(code);
    if (trip.sessionLink.isNotEmpty) return trip.sessionLink;
    return buildTripLink(trip.id);
  }

  /// Shares [link] via the platform share sheet when available; always
  /// copies it to the clipboard. Returns the link that was shared/copied.
  Future<String> share(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (!kIsWeb) {
      try {
        await SharePlus.instance.share(
          ShareParams(text: link, subject: 'Join my Road Song trip'),
        );
      } catch (_) {
        // Share sheet unavailable (e.g. desktop without a handler): the
        // clipboard copy above already succeeded.
      }
    }
    return link;
  }

  /// Copies [link] to the clipboard without opening a share sheet.
  Future<void> copy(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
  }
}
