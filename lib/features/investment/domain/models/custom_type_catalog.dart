import 'package:inv_tracker/core/utils/custom_type_label.dart';
import 'package:inv_tracker/features/investment/domain/entities/custom_investment_type_entity.dart';

/// Why a change to the custom types was not made.
enum CustomTypeIssue { blank, tooLong, atCapacity, duplicate, notFound }

/// The outcome of a change to the custom types. [write] is the one definition
/// to store, or null when nothing needs writing; [result] is the definition
/// the change ended with. [issue] is set when the change was refused.
class CustomTypeChange {
  const CustomTypeChange({this.write, this.result, this.issue});

  const CustomTypeChange.refused(CustomTypeIssue this.issue)
    : write = null,
      result = null;

  final CustomInvestmentType? write;
  final CustomInvestmentType? result;
  final CustomTypeIssue? issue;
}

/// What an investment stores for its custom type: the id of the definition it
/// refers to (null for a label used on that investment only) and its own copy
/// of the label (null for no custom type).
class CustomTypeLink {
  const CustomTypeLink({this.id, this.label});

  static const none = CustomTypeLink();

  final String? id;
  final String? label;
}

/// The rules for an account's custom investment types (#936), as pure
/// functions: they decide what to write and the caller writes it. Every
/// change touches one definition, never an investment or a cash flow.
abstract final class CustomTypeCatalog {
  /// The active types to suggest: one per key (the oldest wins when devices
  /// saved the same label while offline), by label ignoring case.
  static List<CustomInvestmentType> suggestions(
    List<CustomInvestmentType> all,
  ) {
    final byKey = <String, CustomInvestmentType>{};
    for (final def in all) {
      if (def.isRemoved) continue;
      final current = byKey[def.key];
      if (current == null || _isOlder(def, current)) byKey[def.key] = def;
    }
    final result = byKey.values.toList()
      ..sort((a, b) {
        final byLabel = a.key.compareTo(b.key);
        return byLabel != 0 ? byLabel : a.id.compareTo(b.id);
      });
    return result;
  }

  /// Saves [raw] as a reusable type. An existing active type with the same
  /// key is returned with nothing to write; a removed one is revived (same
  /// id, its own casing); otherwise a new one is created, unless the account
  /// already has [CustomTypeLabel.maxActiveDefinitions] active types.
  static CustomTypeChange save(
    List<CustomInvestmentType> all,
    String? raw, {
    required String newId,
    required DateTime now,
  }) {
    final label = CustomTypeLabel.clean(raw);
    if (label.isEmpty) {
      return const CustomTypeChange.refused(CustomTypeIssue.blank);
    }
    if (CustomTypeLabel.exceedsMaxLength(label)) {
      return const CustomTypeChange.refused(CustomTypeIssue.tooLong);
    }
    final key = CustomTypeLabel.keyOf(label);
    final sameKey = all.where((d) => d.key == key).toList();

    final active = _oldest(sameKey.where((d) => !d.isRemoved));
    if (active != null) return CustomTypeChange(result: active);

    if (suggestions(all).length >= CustomTypeLabel.maxActiveDefinitions) {
      return const CustomTypeChange.refused(CustomTypeIssue.atCapacity);
    }

    final removed = _oldest(sameKey);
    if (removed != null) {
      final revived = removed.copyWith(updatedAt: now, clearRemoved: true);
      return CustomTypeChange(write: revived, result: revived);
    }
    final created = CustomInvestmentType(
      id: newId,
      label: label,
      createdAt: now,
      updatedAt: now,
    );
    return CustomTypeChange(write: created, result: created);
  }

  /// Renames the definition [id]. Another definition, active or removed,
  /// with the same key refuses it; changing only the case or spacing of the
  /// type's own name is allowed.
  static CustomTypeChange rename(
    List<CustomInvestmentType> all,
    String id,
    String? raw, {
    required DateTime now,
  }) {
    final target = _byId(all, id);
    if (target == null || target.isRemoved) {
      return const CustomTypeChange.refused(CustomTypeIssue.notFound);
    }
    final label = CustomTypeLabel.clean(raw);
    if (label.isEmpty) {
      return const CustomTypeChange.refused(CustomTypeIssue.blank);
    }
    if (CustomTypeLabel.exceedsMaxLength(label)) {
      return const CustomTypeChange.refused(CustomTypeIssue.tooLong);
    }
    final key = CustomTypeLabel.keyOf(label);
    if (all.any((d) => d.id != id && d.key == key)) {
      return const CustomTypeChange.refused(CustomTypeIssue.duplicate);
    }
    if (label == target.label) return CustomTypeChange(result: target);
    final renamed = target.copyWith(label: label, updatedAt: now);
    return CustomTypeChange(write: renamed, result: renamed);
  }

  /// Removes the definition [id] from the suggestions. Its label stays, and
  /// so does every investment that uses it.
  static CustomTypeChange remove(
    List<CustomInvestmentType> all,
    String id, {
    required DateTime now,
  }) {
    final target = _byId(all, id);
    if (target == null) {
      return const CustomTypeChange.refused(CustomTypeIssue.notFound);
    }
    if (target.isRemoved) return CustomTypeChange(result: target);
    final removed = target.copyWith(removedAt: now, updatedAt: now);
    return CustomTypeChange(write: removed, result: removed);
  }

  /// What an investment saves for the text [raw] typed in its form.
  ///
  /// Text equal to the label the investment already has keeps that label and
  /// link as they are, so editing something else never unlinks it after its
  /// type was renamed. Other text that matches an active type links to it and
  /// takes its casing; anything else is a label for that investment only.
  /// The caller checks the length first (see [CustomTypeLabel.maxLength]).
  static CustomTypeLink resolveForInvestment(
    List<CustomInvestmentType> all,
    String? raw, {
    String? existingId,
    String? existingLabel,
  }) {
    final label = CustomTypeLabel.clean(raw);
    if (label.isEmpty) return CustomTypeLink.none;
    if (existingLabel != null && label == existingLabel) {
      return CustomTypeLink(id: existingId, label: existingLabel);
    }
    final key = CustomTypeLabel.keyOf(label);
    final match = _oldest(all.where((d) => !d.isRemoved && d.key == key));
    if (match != null) return CustomTypeLink(id: match.id, label: match.label);
    return CustomTypeLink(label: label);
  }

  static CustomInvestmentType? _byId(
    List<CustomInvestmentType> all,
    String id,
  ) {
    for (final def in all) {
      if (def.id == id) return def;
    }
    return null;
  }

  static CustomInvestmentType? _oldest(Iterable<CustomInvestmentType> defs) {
    CustomInvestmentType? oldest;
    for (final def in defs) {
      if (oldest == null || _isOlder(def, oldest)) oldest = def;
    }
    return oldest;
  }

  static bool _isOlder(CustomInvestmentType a, CustomInvestmentType b) {
    final byTime = a.createdAt.compareTo(b.createdAt);
    return byTime != 0 ? byTime < 0 : a.id.compareTo(b.id) < 0;
  }
}
