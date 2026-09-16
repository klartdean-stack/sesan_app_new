from pathlib import Path

p = Path('lib/product_detail.dart')
s = p.read_text()


def require(text: str, label: str) -> None:
    if text not in s:
        raise SystemExit(f'{label} not found; refusing unsafe patch')


if "import 'package:flutter/foundation.dart';" not in s:
    s = s.replace(
        "import 'package:flutter/material.dart';\n",
        "import 'package:flutter/material.dart';\nimport 'package:flutter/foundation.dart';\n",
        1,
    )

if '_webGalleryController' not in s:
    anchor = "  String? _translatedDescription;\n"
    require(anchor, 'controller anchor')
    s = s.replace(
        anchor,
        anchor
        + "  final PageController _webGalleryController = PageController();\n"
        + "  final ScrollController _webCommentsController = ScrollController();\n",
        1,
    )

if '_webGalleryController.dispose();' not in s:
    anchor = "    _linkSubscription?.cancel();\n    super.dispose();\n"
    require(anchor, 'dispose anchor')
    s = s.replace(
        anchor,
        "    _linkSubscription?.cancel();\n"
        "    _webGalleryController.dispose();\n"
        "    _webCommentsController.dispose();\n"
        "    super.dispose();\n",
        1,
    )

map_anchor = "markers: {Marker(markerId: const MarkerId('product_preview'), position: location)}, myLocationButtonEnabled: false"
if map_anchor in s:
    s = s.replace(
        map_anchor,
        "markers: {Marker(markerId: const MarkerId('product_preview'), position: location)}, liteModeEnabled: !kIsWeb, myLocationButtonEnabled: false",
        1,
    )

if 'controller: _webGalleryController,' not in s:
    anchor = "                        child: PageView.builder(\n                          itemCount: totalSlides,"
    require(anchor, 'PageView anchor')
    s = s.replace(
        anchor,
        "                        child: PageView.builder(\n"
        "                          controller: _webGalleryController,\n"
        "                          itemCount: totalSlides,",
        1,
    )

if 'Widget _buildGalleryThumbnails' not in s:
    anchor = '  double? _mapCoordinate(dynamic value) {'
    require(anchor, 'helper insertion anchor')
    helpers = r'''  Widget _buildGalleryThumbnails({
    required List<String> images,
    required bool hasVideo,
  }) {
    final total = images.length + (hasVideo ? 1 : 0);
    if (total <= 1) return const SizedBox.shrink();
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        itemCount: total,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final selected = _currentPage == index;
          final isVideo = hasVideo && index == images.length;
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _webGalleryController.animateToPage(
              index,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 48,
              height: 48,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: isVideo ? Colors.black : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? Colors.blue : Colors.grey.shade300,
                  width: selected ? 2.5 : 1,
                ),
              ),
              child: isVideo
                  ? const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28)
                  : CachedNetworkImage(
                      imageUrl: images[index],
                      fit: BoxFit.cover,
                      memCacheWidth: 144,
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.broken_image_outlined, size: 20),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWebGalleryExtras({
    required List<String> images,
    required bool hasVideo,
  }) {
    final sellerId = (widget.product['seller_id'] ?? '').toString();
    final sellerName = (widget.product['seller_name'] ??
            appText(context, km: 'អ្នកលក់', en: 'Seller'))
        .toString();
    final sellerPhoto = (widget.product['seller_photo'] ?? '').toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildGalleryThumbnails(images: images, hasVideo: hasVideo),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          color: const Color(0xFFF4FAF1),
          child: ListTile(
            onTap: sellerId.isEmpty
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SellerProfileScreen(
                          sellerId: sellerId,
                          sellerName: sellerName,
                        ),
                      ),
                    ),
            leading: CircleAvatar(
              backgroundImage:
                  sellerPhoto.isNotEmpty ? NetworkImage(sellerPhoto) : null,
              child: sellerPhoto.isEmpty
                  ? const Icon(Icons.storefront)
                  : null,
            ),
            title: Text(
              sellerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              appText(context, km: 'ព័ត៌មានអ្នកលក់', en: 'Seller information'),
            ),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE1E6ED)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appText(context, km: 'សុវត្ថិភាពអ្នកទិញ', en: 'Buyer protection'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(appText(
                context,
                km: '✓ ពិនិត្យព័ត៌មានអ្នកលក់មុនទិញ',
                en: '✓ Check seller information before buying',
              )),
              Text(appText(
                context,
                km: '✓ អាចដាក់បណ្ដឹងតាម Sesan',
                en: '✓ Report an issue through Sesan',
              )),
            ],
          ),
        ),
        if (widget.product['id'] != null &&
            widget.product['id'].toString().isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            height: 420,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE1E6ED)),
            ),
            child: Scrollbar(
              controller: _webCommentsController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _webCommentsController,
                child: CommentSection(
                  productId: widget.product['id'],
                  sellerId: widget.product['seller_id'] ?? '',
                  currentUserId: _currentUserId,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

'''
    s = s.replace(anchor, helpers + anchor, 1)

if 'final isDesktop = constraints.maxWidth >= 900;' not in s:
    opening_old = '''            constraints: const BoxConstraints(maxWidth: 1000),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ១. រូបភាពស្លាយ
                  // ១. រូបភាពស្លាយ (Square 1:1)
                  Stack('''
    opening_new = '''            constraints: const BoxConstraints(maxWidth: 1200),
            child: SingleChildScrollView(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= 900;
                  final galleryWidth = isDesktop ? 520.0 : constraints.maxWidth;
                  final detailsWidth = isDesktop
                      ? constraints.maxWidth - galleryWidth - 20
                      : constraints.maxWidth;
                  return Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.start,
                    spacing: 20,
                    runSpacing: isDesktop ? 20 : 0,
                    children: [
                      SizedBox(
                        width: galleryWidth,
                        child: Column(
                          children: [
                            Stack('''
    require(opening_old, 'responsive opening')
    s = s.replace(opening_old, opening_new, 1)

    split_old = '''                  ),
                  // ... កូដផ្នែកខាងក្រោមរបស់មេ
                  Padding(
                    padding: const EdgeInsets.all(15.0),'''
    split_new = '''                  ),
                            if (!isDesktop)
                              _buildGalleryThumbnails(
                                images: displayImages,
                                hasVideo: hasVideo,
                              ),
                            if (isDesktop)
                              _buildWebGalleryExtras(
                                images: displayImages,
                                hasVideo: hasVideo,
                              ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: detailsWidth,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            15,
                            isDesktop ? 15 : 4,
                            15,
                            15,
                          ),'''
    require(split_old, 'responsive split')
    s = s.replace(split_old, split_new, 1)

    comments_old = '''                        // 🎯 ដាក់ចូលក្នុងជួរ 598 (ចន្លោះ ListTile ទីតាំង និង RelatedProducts)
                        const SizedBox(height: 20),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            "មតិយោបល់",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),


                        // ហៅ Widget Comment មកបង្ហាញតែ ១ ដូចដែលមេចង់បាន
                        // កុំឱ្យវាហៅ CommentSection បើអត់មាន ID ពិតប្រាកដ
                        if (widget.product['id'] != null &&
                            widget.product['id'].toString().isNotEmpty)
                          CommentSection(
                            productId: widget.product['id'],
                            sellerId: widget.product['seller_id'] ?? '',
                            currentUserId: _currentUserId, // ✅ បន្ថែមអង្គនេះ
                          )
                        else
                          const Center(child: Text("មិនមានទិន្នន័យផលិតផល")),
                        const SizedBox(height: 30),'''
    comments_new = '''                        if (!isDesktop) ...[
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              appText(context, km: 'មតិយោបល់', en: 'Comments'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (widget.product['id'] != null &&
                              widget.product['id'].toString().isNotEmpty)
                            CommentSection(
                              productId: widget.product['id'],
                              sellerId: widget.product['seller_id'] ?? '',
                              currentUserId: _currentUserId,
                            )
                          else
                            Center(
                              child: Text(appText(
                                context,
                                km: 'មិនមានទិន្នន័យផលិតផល',
                                en: 'No product data',
                              )),
                            ),
                          const SizedBox(height: 30),
                        ],'''
    require(comments_old, 'responsive comments')
    s = s.replace(comments_old, comments_new, 1)

    tail_old = '''                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),'''
    tail_new = '''                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  ),
),'''
    require(tail_old, 'responsive closing')
    s = s.replace(tail_old, tail_new, 1)

p.write_text(s)
