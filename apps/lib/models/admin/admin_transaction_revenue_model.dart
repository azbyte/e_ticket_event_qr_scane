/// Admin transactions and platform revenue models (PRD Section 6.7, FR-89 s.d. FR-93).
library;

class AdminRevenueSummary {
  final double grossTicketSales; // Total ticket sales volume (Organizer gross)
  final double ticketCommissionRevenue; // Platform commission from ticket sales
  final double packageRevenue; // Revenue from subscription packages
  final double totalPlatformRevenue; // ticketCommissionRevenue + packageRevenue
  final int totalTicketOrders;
  final int totalPackageInvoices;
  final String period; // 'all', 'today', 'this_week', 'this_month', 'this_year'

  const AdminRevenueSummary({
    required this.grossTicketSales,
    required this.ticketCommissionRevenue,
    required this.packageRevenue,
    required this.totalPlatformRevenue,
    required this.totalTicketOrders,
    required this.totalPackageInvoices,
    required this.period,
  });
}

class AdminTicketTransactionModel {
  final String id;
  final String orderId;
  final String eventId;
  final String eventTitle;
  final String organizerId;
  final String organizerName;
  final String customerName;
  final double grossAmount;
  final double commissionRateSnapshot; // e.g. 0.05 (5%)
  final double commissionAmount; // grossAmount * commissionRateSnapshot
  final double netOrganizerAmount; // grossAmount - commissionAmount
  final String paymentMethod;
  final String status; // 'PAID', 'PENDING', 'REFUNDED'
  final DateTime createdAt;

  const AdminTicketTransactionModel({
    required this.id,
    required this.orderId,
    required this.eventId,
    required this.eventTitle,
    required this.organizerId,
    required this.organizerName,
    required this.customerName,
    required this.grossAmount,
    required this.commissionRateSnapshot,
    required this.commissionAmount,
    required this.netOrganizerAmount,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
  });
}

class AdminPackageTransactionModel {
  final String id;
  final String invoiceNumber;
  final String subscriptionId;
  final String organizerId;
  final String organizerName;
  final String planId;
  final String planName;
  final double amount;
  final String paymentMethod;
  final String status; // 'PAID', 'PENDING', 'FAILED'
  final DateTime createdAt;

  const AdminPackageTransactionModel({
    required this.id,
    required this.invoiceNumber,
    required this.subscriptionId,
    required this.organizerId,
    required this.organizerName,
    required this.planId,
    required this.planName,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
  });
}

