import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Swipeable image carousel for multi-image posts.
/// Shows a PageView with dot indicators and a counter badge.
/// Tap on an image opens fullscreen via [onTap] callback.
class PostCarouselViewer extends StatefulWidget {
  const PostCarouselViewer({
    super.key,
    required this.imageUrls,
    this.onDoubleTap,
    this.onTap,
  });

  final List<String> imageUrls;
  final VoidCallback? onDoubleTap;
  /// Called when user taps an image. Passes the current page index.
  final void Function(int index)? onTap;

  @override
  State<PostCarouselViewer> createState() => _PostCarouselViewerState();
}

class _PostCarouselViewerState extends State<PostCarouselViewer> {
  final _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageCount = widget.imageUrls.length;
    if (imageCount == 0) return const SizedBox.shrink();

    return GestureDetector(
      onDoubleTap: widget.onDoubleTap,
      onTap: widget.onTap != null ? () => widget.onTap!(_currentPage) : null,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // ── PageView ──
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 500),
            child: AspectRatio(
              aspectRatio: 1.0, // square default
              child: PageView.builder(
                controller: _controller,
                itemCount: imageCount,
                onPageChanged: (page) => setState(() => _currentPage = page),
                itemBuilder: (context, index) {
                  return CachedNetworkImage(
                    imageUrl: widget.imageUrls[index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (_, __) => Container(
                      color: Colors.black,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.black,
                      child: Center(
                        child: Icon(
                          Icons.broken_image_rounded,
                          color: Colors.white.withValues(alpha: 0.3),
                          size: 40,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ── Counter badge (top right) ──
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_currentPage + 1}/$imageCount',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // ── Dot indicators ──
          if (imageCount > 1 && imageCount <= 10)
            Positioned(
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    imageCount,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      width: i == _currentPage ? 8 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: i == _currentPage
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
