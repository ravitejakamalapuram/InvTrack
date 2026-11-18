/// One-time invite to the InvTrack tips channel on Telegram, and the one place
/// that opens it (Overview card and Settings row). See
/// design/system/components/TelegramInviteCard.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/features/auth/presentation/providers/guest_link_banner_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/settings/presentation/providers/sample_data_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

const telegramChannelUrl = 'https://t.me/invtrack_tips';
const telegramInviteDoneKey = 'telegram_invite_done';
const telegramInviteMinInvestments = 3;

/// Opens a URL outside the app; tests replace it.
final telegramLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// True once the user joined or dismissed the card (device-local, forever).
class TelegramInviteDoneNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(telegramInviteDoneKey) ??
      false;

  Future<void> markDone() async {
    state = true;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(telegramInviteDoneKey, true);
  }
}

final telegramInviteDoneProvider =
    NotifierProvider<TelegramInviteDoneNotifier, bool>(
      TelegramInviteDoneNotifier.new,
    );

/// From the 3rd investment, until joined or dismissed; never in sample-data
/// mode, and never next to the guest backup banner.
final telegramInviteVisibleProvider = Provider<bool>((ref) {
  if (ref.watch(telegramInviteDoneProvider)) return false;
  if (ref.watch(sampleDataModeProvider).isActive) return false;
  if (ref.watch(guestLinkBannerVisibleProvider)) return false;
  final count = ref.watch(
    activeInvestmentsProvider.select((a) => a.value?.length ?? 0),
  );
  return count >= telegramInviteMinInvestments;
});

/// Opens the channel and logs the tap. [source] is `card` or `settings`.
/// Returns whether it opened; if not, tells the user the link.
Future<bool> openTelegramChannel(
  BuildContext context,
  WidgetRef ref, {
  required String source,
}) async {
  ref.read(analyticsServiceProvider).logTelegramInviteTapped(source: source);
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  var opened = false;
  try {
    opened = await ref.read(telegramLauncherProvider)(
      Uri.parse(telegramChannelUrl),
    );
  } catch (_) {}
  if (!opened) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.telegramInviteOpenFailed)),
    );
  }
  return opened;
}
