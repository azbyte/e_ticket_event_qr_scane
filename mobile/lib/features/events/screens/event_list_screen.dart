import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/event_provider.dart';
import '../../orders/screens/order_list_screen.dart';
import '../../tickets/screens/ticket_list_screen.dart';
import '../widgets/event_card.dart';

/// Event list screen for attendees (PRD sections 7.2 B, 3.1 #3).
class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key});

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  final EventProvider _provider = EventProvider.instance;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'Semua',
    'Teknologi',
    'Musik',
    'Workshop',
    'Seminar',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider.loadEvents();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _provider.loadEvents(
      search: value,
      category: _provider.selectedCategory,
    );
  }

  void _onCategorySelected(String category) {
    _provider.setSelectedCategory(category);
    _provider.loadEvents(
      search: _searchController.text,
      category: category,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Jelajahi Event',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.confirmation_number_outlined),
            tooltip: 'Tiket Saya',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TicketListScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Riwayat Pesanan',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OrderListScreen()),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _provider,
        builder: (context, _) {
          return RefreshIndicator(
            onRefresh: () => _provider.loadEvents(
              search: _searchController.text,
              category: _provider.selectedCategory,
            ),
            child: CustomScrollView(
              slivers: [
                // Search Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Cari event, konser, seminar, lokasi...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                ),

                // Category Chips
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 52,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final isSelected = _provider.selectedCategory == cat;
                        return ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryColor,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (_) => _onCategorySelected(cat),
                        );
                      },
                    ),
                  ),
                ),

                // Main Content States
                if (_provider.isLoading)
                  const SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Memuat daftar event...', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                else if (_provider.error != null)
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
                            const SizedBox(height: 16),
                            Text(
                              _provider.error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 15),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _provider.loadEvents(),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (_provider.events.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy, size: 70, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text(
                            'Tidak ada event ditemukan',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Coba gunakan kata kunci pencarian atau kategori lain.',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final event = _provider.events[index];
                        return EventCard(event: event);
                      },
                      childCount: _provider.events.length,
                    ),
                  ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 24),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
