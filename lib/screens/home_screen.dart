import 'package:flutter/material.dart';

import '../models/item_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/home_carousel.dart';
import '../widgets/item_card.dart';
import '../widgets/search_bar.dart';
import 'borrowing_history_screen.dart';
import 'item_detail_screen.dart';
import 'inventory_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = AuthService();
  final _firestore = FirestoreService();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  late final Stream<List<ItemModel>> _itemsStream = _firestore.getItems();
  int _selectedIndex = 0;
  String _search = '';
  String _category = 'Semua';

  Future<void> _logout() async {
    try {
      await _auth.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (error) {
      _message('Gagal logout: $error');
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  void _openHistory() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BorrowingHistoryScreen()),
      );

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _dashboard(),
            const InventoryScreen(),
            ProfileScreen(onLogout: _logout),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) => setState(() => _selectedIndex = index),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Beranda'),
            NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Inventaris'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
          ],
        ),
      );

  Widget _dashboard() => StreamBuilder<List<ItemModel>>(
        stream: _itemsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Gagal memuat data: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data ?? [];
          final categories = items
              .map((item) => item.category)
              .where((e) => e.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
          final query = _search.toLowerCase().trim();
          final filtered = items.where((item) {
            final matchesText = '${item.name} ${item.category} ${item.code}'.toLowerCase().contains(query);
            return matchesText && (_category == 'Semua' || item.category == _category);
          }).toList();
          final available = items.where((item) => item.status == 'Available').length;
          final borrowed = items.length - available;

          return SafeArea(
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _PinnedHomeHeader(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: (value) => setState(() => _search = value),
                    onHistory: _openHistory,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const HomeCarousel(),
                      const SizedBox(height: 18),
                      Row(children: [
                        Expanded(child: _statCard('Total alat', items.length, Icons.inventory_2_outlined)),
                        const SizedBox(width: 10),
                        Expanded(child: _statCard('Tersedia', available, Icons.check_circle_outline)),
                        const SizedBox(width: 10),
                        Expanded(child: _statCard('Dipinjam', borrowed, Icons.schedule)),
                      ]),
                      const SizedBox(height: 22),
                      const Text('Kategori', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: ['Semua', ...categories].map((category) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(category),
                              selected: _category == category,
                              onSelected: (_) => setState(() => _category = category),
                            ),
                          )).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(children: [
                        const Expanded(child: Text('Daftar alat', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                        Text('${filtered.length} alat', style: const TextStyle(color: Colors.black54)),
                      ]),
                      const SizedBox(height: 10),
                      if (filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Center(child: Text('Alat tidak ditemukan.')),
                        )
                      else
                        SizedBox(
                          height: 190,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 10),
                            itemBuilder: (_, index) => ItemCard(
                              item: filtered[index],
                              compact: true,
                              onTap: () => _showItemDetails(filtered[index]),
                            ),
                          ),
                        ),
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _selectedIndex = 1),
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: const Text('Lihat semua inventaris'),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      );

  Widget _statCard(String title, int count, IconData icon) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
          child: Column(children: [
            Icon(icon, color: const Color(0xFF1769AA)),
            const SizedBox(height: 4),
            Text('$count', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ]),
        ),
      );

  void _showItemDetails(ItemModel item) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)),
    );
  }

}

class _PinnedHomeHeader extends SliverPersistentHeaderDelegate {
  _PinnedHomeHeader({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onHistory,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onHistory;

  @override
  // Keep enough height for the title/subtitle row and the search field.
  // The title Column needs 50 px; 40 px caused a 7 px RenderFlex overflow.
  double get minExtent => 146;

  @override
  double get maxExtent => 146;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: const Color(0xFFF5F8FC),
      elevation: overlapsContent ? 2 : 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 7, 18, 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE8EDF2))),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 50,
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PustakaLab', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1769AA))),
                        Text('Inventaris laboratorium', style: TextStyle(fontSize: 11, color: Colors.black54)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Riwayat peminjaman',
                    onPressed: onHistory,
                    icon: const Icon(Icons.history, size: 25),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            PustakaSearchBar(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedHomeHeader oldDelegate) =>
      controller != oldDelegate.controller ||
      focusNode != oldDelegate.focusNode ||
      onChanged != oldDelegate.onChanged ||
      onHistory != oldDelegate.onHistory;
}
