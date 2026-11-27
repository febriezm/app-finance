import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router.dart';
import '../../../../core/utils/app_haptics.dart';

/// Halaman Landing / Sambutan (Landing Page) — Modern & Clean Onboarding UI.
///
/// Terinspirasi dari desain visual finansial modern (blu.fin style):
/// - Latar belakang monokromatis artistik dengan gradasi gelap menyatu (*fade to deep dark*).
/// - Lencana brand modern dinamis: "my.fin" / MyFinance.
/// - Indikator slide minimalis (`— • •`) dengan headline yang elegan dan tidak kaku.
/// - Tombol aksi utama berbentuk pill biru dengan ikon panah melingkar ("Mulai Sekarang ➔").
/// - Tautan sekunder ramah sentuhan ("Sudah Memiliki Akun? Masuk") tanpa garis bawah.
class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_LandingSlideData> _slides = const [
    _LandingSlideData(
      tag: 'Buku Besar Presisi',
      headline: 'Kelola Keuangan Pribadi\nJadi Lebih Teratur.',
      description:
          'Pantau arus kas harian, integrasikan rekening bank dan e-wallet dalam satu aplikasi finansial yang tenang, privat, dan tanpa kerumitan.',
    ),
    _LandingSlideData(
      tag: 'Pemindai Struk OCR',
      headline: 'Ekstraksi Struk Belanja\nOtomatis & Cepat.',
      description:
          'Foto atau unggah struk belanja Anda untuk pencatatan transaksi instan tanpa perlu repot mengetik rincian belanja manual satu per satu.',
    ),
    _LandingSlideData(
      tag: 'Privasi & Cloud RLS',
      headline: 'Penyimpanan Terenkripsi\nDengan Proteksi PIN.',
      description:
          'Data keuangan Anda terisolasi aman dengan enkripsi cloud Supabase PostgreSQL, terlindungi kode sandi PIN 6-digit, dan Face ID.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showInfoSheet(BuildContext context) {
    unawaited(AppHaptics.light());
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MyFinance',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Full Cloud Supabase & Ledger Invariance',
                            style: TextStyle(
                              color: Color(0xFF60A5FA),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Zero Rounding Error',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'MyFinance dirancang dengan arsitektur buku besar integer Rupiah tanpa celah pembulatan, penyimpanan privat terenkripsi Row Level Security (RLS) di Supabase, dan perlindungan keamanan biometrik perangkat.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const deepBackground = Color(0xFF0B0F19);

    return Scaffold(
      backgroundColor: deepBackground,
      body: Stack(
        children: [
          // 1. Atmospheric Top Background Image
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.58,
            child: Image.asset(
              'assets/images/landing_hero_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF1E293B), Color(0xFF0B0F19)],
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. Smooth Vignette & Dark Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.28, 0.54, 0.76, 1.0],
                  colors: [
                    Color(0x66000000),
                    Color(0x33000000),
                    Color(0xB30B0F19),
                    Color(0xFA0B0F19),
                    deepBackground,
                  ],
                ),
              ),
            ),
          ),

          // 3. Foreground Interactive UI
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: constraints.maxWidth < 360 ? 16 : 24,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Top Bar: Info Icon (!) on the right
                            Align(
                              alignment: Alignment.centerRight,
                              child: InkWell(
                                onTap: () => _showInfoSheet(context),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withValues(alpha: 0.35),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.25),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.info_outline_rounded,
                                      color: Colors.white,
                                      size: 19,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Hero Brand Badge: "my.fin" / MyFinance
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildBrandBadge(),
                                  const SizedBox(height: 10),
                                  Text(
                                    'MyFinance',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2.2,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.4),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.12),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        'Full Cloud Supabase & Ledger Invariance',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white.withValues(alpha: 0.7),
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const Spacer(),
                            const SizedBox(height: 28),

                            // Indicator Dots (— • •)
                            Row(
                              children: List.generate(_slides.length, (index) {
                                final isActive = _currentPage == index;
                                return GestureDetector(
                                  onTap: () {
                                    _pageController.animateToPage(
                                      index,
                                      duration: const Duration(milliseconds: 350),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    margin: const EdgeInsets.only(right: 6),
                                    width: isActive ? 28 : 7,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                );
                              }),
                            ),

                            const SizedBox(height: 16),

                            // Swipeable Content Slider
                            SizedBox(
                              height: 176,
                              child: PageView.builder(
                                controller: _pageController,
                                itemCount: _slides.length,
                                onPageChanged: (index) {
                                  setState(() {
                                    _currentPage = index;
                                  });
                                },
                                itemBuilder: (context, index) {
                                  final slide = _slides[index];
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Category Pill
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2563EB).withValues(alpha: 0.22),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: const Color(0xFF3B82F6).withValues(alpha: 0.45),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          slide.tag,
                                          style: const TextStyle(
                                            color: Color(0xFF93C5FD),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      // Main Headline
                                      Text(
                                        slide.headline,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5,
                                          height: 1.22,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),

                                      // Description
                                      Text(
                                        slide.description,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.72),
                                          fontSize: 13,
                                          height: 1.45,
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Main Primary Action Pill Button ("Mulai Sekarang ➔")
                            InkWell(
                              onTap: () {
                                unawaited(AppHaptics.medium());
                                final router = GoRouter.maybeOf(context);
                                if (router != null) {
                                  router.go(AppRouter.register);
                                } else {
                                  context.push(AppRouter.register);
                                }
                              },
                              borderRadius: BorderRadius.circular(28),
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.45),
                                      blurRadius: 20,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Mulai Sekarang',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.arrow_forward_rounded,
                                            color: Color(0xFF1D4ED8),
                                            size: 19,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Secondary Action ("Sudah Memiliki Akun? Masuk")
                            Center(
                              child: TextButton(
                                onPressed: () {
                                  unawaited(AppHaptics.light());
                                  final router = GoRouter.maybeOf(context);
                                  if (router != null) {
                                    router.go(AppRouter.login);
                                  } else {
                                    context.push(AppRouter.login);
                                  }
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Sudah Memiliki Akun? Masuk',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Footer: Term of Use & Privacy
                            Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Term of Use • Privacy & Cookies • Version 1.0.0',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    fontSize: 11,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Modern Slanted Pill Brand Badge: "my.fin"
  Widget _buildBrandBadge() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Transform(
        transform: Matrix4.skewX(-0.14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 7, 7, 7),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.55),
                blurRadius: 26,
                offset: const Offset(0, 8),
                spreadRadius: 1,
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'my.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(width: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'fin',
                  style: TextStyle(
                    color: Color(0xFF1E40AF),
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandingSlideData {
  final String tag;
  final String headline;
  final String description;

  const _LandingSlideData({
    required this.tag,
    required this.headline,
    required this.description,
  });
}
