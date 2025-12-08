import 'package:flutter/material.dart';

/// Investment Status - lifecycle states
enum InvestmentStatus {
  open,
  closed;

  String get displayName {
    switch (this) {
      case InvestmentStatus.open:
        return 'Open';
      case InvestmentStatus.closed:
        return 'Closed';
    }
  }

  static InvestmentStatus fromString(String value) {
    return InvestmentStatus.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => InvestmentStatus.open,
    );
  }
}

/// Investment Types - for alternative investments
enum InvestmentType {
  p2pLending,
  fixedDeposit,
  bonds,
  realEstate,
  privateEquity,
  angelInvesting,
  chitFunds,
  gold,
  crypto,
  mutualFunds,
  stocks,
  other;

  String get displayName {
    switch (this) {
      case InvestmentType.p2pLending:
        return 'P2P Lending';
      case InvestmentType.fixedDeposit:
        return 'Fixed Deposit';
      case InvestmentType.bonds:
        return 'Bonds/Debentures';
      case InvestmentType.realEstate:
        return 'Real Estate';
      case InvestmentType.privateEquity:
        return 'Private Equity';
      case InvestmentType.angelInvesting:
        return 'Angel Investing';
      case InvestmentType.chitFunds:
        return 'Chit Funds';
      case InvestmentType.gold:
        return 'Gold/Commodities';
      case InvestmentType.crypto:
        return 'Crypto';
      case InvestmentType.mutualFunds:
        return 'Mutual Funds';
      case InvestmentType.stocks:
        return 'Stocks';
      case InvestmentType.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case InvestmentType.p2pLending:
        return Icons.handshake_rounded;
      case InvestmentType.fixedDeposit:
        return Icons.account_balance_rounded;
      case InvestmentType.bonds:
        return Icons.description_rounded;
      case InvestmentType.realEstate:
        return Icons.home_rounded;
      case InvestmentType.privateEquity:
        return Icons.business_center_rounded;
      case InvestmentType.angelInvesting:
        return Icons.rocket_launch_rounded;
      case InvestmentType.chitFunds:
        return Icons.group_rounded;
      case InvestmentType.gold:
        return Icons.monetization_on_rounded;
      case InvestmentType.crypto:
        return Icons.currency_bitcoin_rounded;
      case InvestmentType.mutualFunds:
        return Icons.pie_chart_rounded;
      case InvestmentType.stocks:
        return Icons.show_chart_rounded;
      case InvestmentType.other:
        return Icons.attach_money_rounded;
    }
  }

  Color get color {
    switch (this) {
      case InvestmentType.p2pLending:
        return const Color(0xFF3B82F6); // Blue
      case InvestmentType.fixedDeposit:
        return const Color(0xFF10B981); // Emerald
      case InvestmentType.bonds:
        return const Color(0xFFF59E0B); // Amber
      case InvestmentType.realEstate:
        return const Color(0xFFEC4899); // Pink
      case InvestmentType.privateEquity:
        return const Color(0xFF8B5CF6); // Purple
      case InvestmentType.angelInvesting:
        return const Color(0xFF06B6D4); // Cyan
      case InvestmentType.chitFunds:
        return const Color(0xFFF97316); // Orange
      case InvestmentType.gold:
        return const Color(0xFFFFD700); // Gold
      case InvestmentType.crypto:
        return const Color(0xFF8B5CF6); // Purple
      case InvestmentType.mutualFunds:
        return const Color(0xFF3B82F6); // Blue
      case InvestmentType.stocks:
        return const Color(0xFF10B981); // Emerald
      case InvestmentType.other:
        return const Color(0xFF6B7280); // Gray
    }
  }

  static InvestmentType fromString(String value) {
    return InvestmentType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => InvestmentType.other,
    );
  }
}

/// Investment Entity for Cash Flow Tracker
class InvestmentEntity {
  final String id;
  final String name;
  final InvestmentType type;
  final InvestmentStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime? closedAt;
  final DateTime updatedAt;

  const InvestmentEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    this.notes,
    required this.createdAt,
    this.closedAt,
    required this.updatedAt,
  });

  bool get isOpen => status == InvestmentStatus.open;
  bool get isClosed => status == InvestmentStatus.closed;

  InvestmentEntity copyWith({
    String? id,
    String? name,
    InvestmentType? type,
    InvestmentStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? closedAt,
    DateTime? updatedAt,
  }) {
    return InvestmentEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      closedAt: closedAt ?? this.closedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InvestmentEntity &&
        other.id == id &&
        other.name == name &&
        other.type == type &&
        other.status == status &&
        other.notes == notes &&
        other.createdAt == createdAt &&
        other.closedAt == closedAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        type.hashCode ^
        status.hashCode ^
        notes.hashCode ^
        createdAt.hashCode ^
        closedAt.hashCode ^
        updatedAt.hashCode;
  }
}
