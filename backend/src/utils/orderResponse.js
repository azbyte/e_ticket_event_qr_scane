const serializePayment = (payment) => ({
  id: payment.id,
  order_id: payment.order_id,
  method: 'virtual_account',
  status: String(payment.status).toLowerCase(),
  amount: Number(payment.amount),
  payment_reference: payment.payment_reference,
  virtual_account_number: payment.virtual_account_number,
  va_bank: payment.virtual_account_bank,
  paid_at: payment.paid_at,
  expired_at: payment.expires_at,
  notes: payment.failure_reason,
});

const serializeOrder = (order) => {
  const payment = order.order_payments?.[0] || null;
  return {
    id: order.id,
    order_number: order.order_number,
    user_id: order.purchaser_id,
    event_id: order.event_id,
    event_title: order.events?.title || '',
    status: String(order.status).toLowerCase(),
    total_amount: Number(order.subtotal),
    service_fee: Number(order.service_fee),
    grand_total: Number(order.grand_total),
    items: (order.order_items || []).map((item) => ({
      id: item.id,
      order_id: item.order_id,
      ticket_type_id: item.ticket_type_id,
      ticket_type_name: item.ticket_types?.name || '',
      quantity: item.quantity,
      unit_price: Number(item.unit_price),
      subtotal: Number(item.subtotal),
    })),
    expires_at: order.expires_at,
    payment_reference: payment?.payment_reference || null,
    created_at: order.created_at,
    updated_at: order.updated_at,
    payment: payment ? serializePayment(payment) : null,
  };
};

module.exports = { serializeOrder, serializePayment };
