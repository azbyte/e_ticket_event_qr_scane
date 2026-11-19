const serializeEventSummary = (event, totals, pendingOrders, participants, checkedIn) => ({
  event_id: event.id,
  status: String(event.status).toLowerCase(),
  tickets_sold: totals.ticketsSold,
  tickets_remaining: totals.ticketsRemaining,
  gross_sales: totals.grossSales,
  pending_orders: pendingOrders,
  participants,
  checked_in: checkedIn,
});

module.exports = { serializeEventSummary };
