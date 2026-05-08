class AutoOrder {
  final int id;
  final int userId;
  final String userDisplayName;
  final String userEmail;
  final int serviceId;
  final String serviceName;
  final double ratePer1k;
  final String targetLink;
  final int totalQuantity;
  final int perRunQuantity;
  final int completedQuantity;
  final int runInterval;
  final int totalRuns;
  final int completedRuns;
  final int failedRuns;
  final String status;
  final double lockedBalance;
  final double spentBalance;
  final double refundedBalance;
  final String? nextRunAt;
  final String? lastRunAt;
  final String? createdAt;
  final String createdBy;
  final int progressPercent;

  AutoOrder({
    required this.id,
    required this.userId,
    required this.userDisplayName,
    required this.userEmail,
    required this.serviceId,
    required this.serviceName,
    required this.ratePer1k,
    required this.targetLink,
    required this.totalQuantity,
    required this.perRunQuantity,
    required this.completedQuantity,
    required this.runInterval,
    required this.totalRuns,
    required this.completedRuns,
    required this.failedRuns,
    required this.status,
    required this.lockedBalance,
    required this.spentBalance,
    required this.refundedBalance,
    this.nextRunAt,
    this.lastRunAt,
    this.createdAt,
    required this.createdBy,
    required this.progressPercent,
  });

  bool get canPause => status == 'active';
  bool get canResume => status == 'paused';
  bool get canCancel => status == 'active' || status == 'paused';
  bool get canForceRun => status == 'active' || status == 'paused';
  bool get canDelete =>
      status == 'completed' || status == 'cancelled' || status == 'failed';

  factory AutoOrder.fromJson(Map<String, dynamic> json) {
    int _i(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
    double _d(dynamic v) => v is double
        ? v
        : (v is int ? v.toDouble() : double.tryParse('$v') ?? 0.0);
    return AutoOrder(
      id: _i(json['id']),
      userId: _i(json['user_id']),
      userDisplayName: '${json['user_display_name'] ?? ''}',
      userEmail: '${json['user_email'] ?? ''}',
      serviceId: _i(json['service_id']),
      serviceName: '${json['service_name'] ?? ''}',
      ratePer1k: _d(json['rate_per_1k']),
      targetLink: '${json['target_link'] ?? ''}',
      totalQuantity: _i(json['total_quantity']),
      perRunQuantity: _i(json['per_run_quantity']),
      completedQuantity: _i(json['completed_quantity']),
      runInterval: _i(json['run_interval']),
      totalRuns: _i(json['total_runs']),
      completedRuns: _i(json['completed_runs']),
      failedRuns: _i(json['failed_runs']),
      status: '${json['status'] ?? 'pending'}',
      lockedBalance: _d(json['locked_balance']),
      spentBalance: _d(json['spent_balance']),
      refundedBalance: _d(json['refunded_balance']),
      nextRunAt: json['next_run_at']?.toString(),
      lastRunAt: json['last_run_at']?.toString(),
      createdAt: json['created_at']?.toString(),
      createdBy: '${json['created_by'] ?? 'admin'}',
      progressPercent: _i(json['progress_percent']),
    );
  }

  static String statusLabel(String s) {
    switch (s) {
      case 'active':
        return 'Aktif';
      case 'paused':
        return 'Duraklatıldı';
      case 'completed':
        return 'Tamamlandı';
      case 'cancelled':
        return 'İptal';
      case 'failed':
        return 'Başarısız';
      case 'pending':
        return 'Bekliyor';
      default:
        return s;
    }
  }
}

class AutoOrderRun {
  final int id;
  final int runNumber;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String status;
  final String? apiOrderId;
  final String? errorMessage;
  final String? scheduledAt;
  final String? startedAt;
  final String? completedAt;

  AutoOrderRun({
    required this.id,
    required this.runNumber,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.status,
    this.apiOrderId,
    this.errorMessage,
    this.scheduledAt,
    this.startedAt,
    this.completedAt,
  });

  factory AutoOrderRun.fromJson(Map<String, dynamic> json) {
    int _i(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
    double _d(dynamic v) => v is double
        ? v
        : (v is int ? v.toDouble() : double.tryParse('$v') ?? 0.0);
    return AutoOrderRun(
      id: _i(json['id']),
      runNumber: _i(json['run_number']),
      quantity: _i(json['quantity']),
      unitPrice: _d(json['unit_price']),
      totalPrice: _d(json['total_price']),
      status: '${json['status'] ?? 'pending'}',
      apiOrderId: json['api_order_id']?.toString(),
      errorMessage: json['error_message']?.toString(),
      scheduledAt: json['scheduled_at']?.toString(),
      startedAt: json['started_at']?.toString(),
      completedAt: json['completed_at']?.toString(),
    );
  }
}

class AutoOrderService {
  final int id;
  final String name;
  final int categoryId;
  final String categoryName;
  final double ratePer1k;
  final int minOrder;
  final int maxOrder;
  final int autoOrderMinPerRun;
  final int autoOrderMaxPerRun;
  final int autoOrderMinInterval;
  final int autoOrderMaxInterval;

  AutoOrderService({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.ratePer1k,
    required this.minOrder,
    required this.maxOrder,
    required this.autoOrderMinPerRun,
    required this.autoOrderMaxPerRun,
    required this.autoOrderMinInterval,
    required this.autoOrderMaxInterval,
  });

  factory AutoOrderService.fromJson(Map<String, dynamic> json) {
    int _i(dynamic v, [int def = 0]) =>
        v is int ? v : int.tryParse('$v') ?? def;
    double _d(dynamic v) => v is double
        ? v
        : (v is int ? v.toDouble() : double.tryParse('$v') ?? 0.0);
    return AutoOrderService(
      id: _i(json['id']),
      name: '${json['name'] ?? ''}',
      categoryId: _i(json['category_id']),
      categoryName: '${json['category_name'] ?? ''}',
      ratePer1k: _d(json['rate_per_1k']),
      minOrder: _i(json['min_order'], 1),
      maxOrder: _i(json['max_order'], 100000),
      autoOrderMinPerRun: _i(json['auto_order_min_per_run'], 10),
      autoOrderMaxPerRun: _i(json['auto_order_max_per_run'], 100000),
      autoOrderMinInterval: _i(json['auto_order_min_interval'], 120),
      autoOrderMaxInterval: _i(json['auto_order_max_interval'], 604800),
    );
  }
}

class AutoOrderInterval {
  final int seconds;
  final String label;
  AutoOrderInterval({required this.seconds, required this.label});

  factory AutoOrderInterval.fromJson(Map<String, dynamic> json) =>
      AutoOrderInterval(
        seconds: json['seconds'] is int
            ? json['seconds']
            : int.tryParse('${json['seconds']}') ?? 0,
        label: '${json['label'] ?? ''}',
      );
}

class AutoOrderStats {
  final int active;
  final int paused;
  final int completed;
  final int failed;
  final int cancelled;
  final int total;
  final double totalLocked;
  final double totalSpent;

  AutoOrderStats({
    required this.active,
    required this.paused,
    required this.completed,
    required this.failed,
    required this.cancelled,
    required this.total,
    required this.totalLocked,
    required this.totalSpent,
  });

  factory AutoOrderStats.fromJson(Map<String, dynamic> json) {
    int _i(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
    double _d(dynamic v) => v is double
        ? v
        : (v is int ? v.toDouble() : double.tryParse('$v') ?? 0.0);
    return AutoOrderStats(
      active: _i(json['active']),
      paused: _i(json['paused']),
      completed: _i(json['completed']),
      failed: _i(json['failed']),
      cancelled: _i(json['cancelled']),
      total: _i(json['total']),
      totalLocked: _d(json['total_locked']),
      totalSpent: _d(json['total_spent']),
    );
  }
}
