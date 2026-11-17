import 'dart:async';

import 'package:flutter/material.dart';

class HomeCarousel extends StatefulWidget {
  const HomeCarousel({super.key});

  @override
  State<HomeCarousel> createState() => _HomeCarouselState();
}

class _HomeCarouselState extends State<HomeCarousel> {
  static const List<_CarouselSlide> _slides = [
    _CarouselSlide(
      eyebrow: 'PENGELOLAAN LABORATORIUM',
      title: 'Inventaris lebih terorganisir',
      description:
          'Cari alat berdasarkan nama, kategori, atau kode dengan mudah.',
      icon: Icons.inventory_2_rounded,
      colors: [Color(0xFF1769AA), Color(0xFF2588C7)],
    ),
    _CarouselSlide(
      eyebrow: 'PEMANTAUAN REAL-TIME',
      title: 'Cek ketersediaan alat',
      description: 'Pantau alat yang tersedia maupun yang sedang dipinjam.',
      icon: Icons.fact_check_rounded,
      colors: [Color(0xFF087F8C), Color(0xFF18A999)],
    ),
    _CarouselSlide(
      eyebrow: 'PEMINJAMAN TERPANTAU',
      title: 'Pengembalian lebih tertata',
      description:
          'Lihat durasi dan batas pengembalian melalui data peminjaman.',
      icon: Icons.event_available_rounded,
      colors: [Color(0xFF5752A2), Color(0xFF8175C9)],
    ),
  ];

  late final PageController _pageController;
  Timer? _autoPlayTimer;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _scheduleAutoPlay();
  }

  void _scheduleAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      if (!_pageController.hasClients) {
        _scheduleAutoPlay();
        return;
      }

      final nextPage = (_activeIndex + 1) % _slides.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onPageChanged(int index) {
    if (!mounted) return;
    setState(() => _activeIndex = index);
    _scheduleAutoPlay();
  }

  void _goToPage(int index) {
    if (!_pageController.hasClients) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 158,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) =>
                _CarouselBanner(slide: _slides[index]),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_slides.length, (index) {
            final selected = index == _activeIndex;
            return GestureDetector(
              onTap: () => _goToPage(index),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: selected ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.black26,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _CarouselSlide {
  const _CarouselSlide({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
    required this.colors,
  });

  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;
  final List<Color> colors;
}

class _CarouselBanner extends StatelessWidget {
  const _CarouselBanner({required this.slide});

  final _CarouselSlide slide;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: slide.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: slide.colors.first.withAlpha(35),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -34,
            top: -56,
            child: Container(
              width: 178,
              height: 178,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(20),
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: -22,
            child: Icon(
              slide.icon,
              size: 116,
              color: Colors.white.withAlpha(28),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 15, 18, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        slide.eyebrow,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withAlpha(220),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        slide.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          height: 1.12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        slide.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withAlpha(225),
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(slide.icon, size: 48, color: Colors.white.withAlpha(235)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
