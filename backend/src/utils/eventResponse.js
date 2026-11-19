const serializeEvent = (event) => {
  if (typeof event.status !== 'string' || typeof event.event_format !== 'string') {
    throw new TypeError('Event status and format are required by the API contract');
  }
  const category = Array.isArray(event.event_categories)
    ? event.event_categories[0]
    : event.event_categories;
  return {
    ...event,
    organizer_id: event.created_by,
    start_date_time: event.event_date,
    event_type: event.event_format.toLowerCase(),
    category: category?.name || null,
    status: event.status.toLowerCase(),
  };
};

module.exports = { serializeEvent };
