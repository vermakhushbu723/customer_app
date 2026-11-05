import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/list_store.dart';
import '../../cart/data/cart_controller.dart';
import '../../../core/storage/local_store.dart';
import '../domain/product.dart';

const _cube = 'assets/images/CubeIce.png';
const _crushed = 'assets/images/CrushedBlockIce.png';
const _dry = 'assets/images/DryIce.png';
const _box = 'assets/images/IceBox.png';

const _notForDrinks =
    'For industrial use and chilling purposes only. Not for human consumption. Use tube ice in crushed form for drinks.';
const _dryIceWarning =
    'Handle with insulated gloves and keep in a ventilated area. Do not touch with bare hands, eat it, or seal it in an airtight container.';

const categories = [
  IceCategory(id: 'tube', name: 'Tube Ice', tagline: 'Clear ice for drinks', image: _cube),
  IceCategory(id: 'cube', name: 'Cube Ice', tagline: 'For parties and bars', image: _cube),
  IceCategory(id: 'crushed', name: 'Crushed Ice', tagline: 'For chilling and displays', image: _crushed),
  IceCategory(id: 'block', name: 'Block Ice', tagline: 'Slow melting', image: _crushed),
  IceCategory(id: 'slab', name: 'Slab Ice', tagline: 'For long cooling', image: _crushed),
  IceCategory(id: 'dry', name: 'Dry Ice', tagline: 'Special cooling and effects', image: _dry),
  IceCategory(id: 'box', name: 'Ice Boxes', tagline: 'Keep ice frozen longer', image: _box),
];

/// Replaced with the server's list as soon as it arrives. Prices here are placeholders.
List<Product> products = const [
  Product(id: 'tube-2', name: 'Tube Ice', categoryId: 'tube', description: 'Clear, hygienic tube ice for everyday drinks at home.', image: _cube, pack: '2 kg bag', weightKg: 2, price: 59, mrp: 70, rating: 4.7, uses: ['Drinks', 'Home'], forDrinks: true, bestseller: true),
  Product(id: 'tube-5', name: 'Tube Ice', categoryId: 'tube', description: 'A bigger pack of tube ice for family get-togethers.', image: _cube, pack: '5 kg bag', weightKg: 5, price: 129, mrp: 150, rating: 4.6, uses: ['Drinks', 'Get-togethers'], forDrinks: true, bestseller: true),
  Product(id: 'tube-20', name: 'Tube Ice', categoryId: 'tube', description: 'Tube ice in a large bag for events and catering.', image: _cube, pack: '20 kg bag', weightKg: 20, price: 420, mrp: 480, rating: 4.6, uses: ['Events', 'Catering'], forDrinks: true),
  Product(id: 'cube-1', name: 'Cube Ice', categoryId: 'cube', description: 'Slow-melting cubes for a small celebration at home.', image: _cube, pack: '1 kg bag', weightKg: 1, price: 39, mrp: 45, rating: 4.8, uses: ['Drinks', 'Home'], forDrinks: true),
  Product(id: 'cube-5', name: 'Cube Ice', categoryId: 'cube', description: 'Party-ready cubes that keep drinks cold for longer.', image: _cube, pack: '5 kg bag', weightKg: 5, price: 149, mrp: 175, rating: 4.8, uses: ['Parties', 'Bars'], forDrinks: true, bestseller: true),
  Product(id: 'cube-20', name: 'Cube Ice', categoryId: 'cube', description: 'A large bag of cubes for bars, weddings and events.', image: _cube, pack: '20 kg bag', weightKg: 20, price: 499, mrp: 560, rating: 4.7, uses: ['Weddings', 'Bars'], forDrinks: true),
  Product(id: 'crushed-5', name: 'Crushed Ice', categoryId: 'crushed', description: 'Crushed ice for seafood displays and chilling.', image: _crushed, pack: '5 kg bag', weightKg: 5, price: 99, mrp: 115, rating: 4.4, uses: ['Seafood displays', 'Chilling'], warning: _notForDrinks),
  Product(id: 'crushed-25', name: 'Crushed Ice', categoryId: 'crushed', description: 'A large bag of crushed ice for shops and displays.', image: _crushed, pack: '25 kg bag', weightKg: 25, price: 349, mrp: 400, rating: 4.3, uses: ['Fish stalls', 'Chilling'], warning: _notForDrinks),
  Product(id: 'block-25', name: 'Block Ice', categoryId: 'block', description: 'A slow-melting block for long cooling.', image: _crushed, pack: '25 kg block', weightKg: 25, price: 249, mrp: 280, rating: 4.5, uses: ['Long cooling', 'Transport'], warning: _notForDrinks),
  Product(id: 'block-50', name: 'Block Ice', categoryId: 'block', description: 'Large, slow-melting block for heavy cooling.', image: _crushed, pack: '50 kg block', weightKg: 50, price: 449, mrp: 500, rating: 4.5, uses: ['Heavy cooling', 'Transport'], warning: _notForDrinks),
  Product(id: 'slab-25', name: 'Slab Ice', categoryId: 'slab', description: 'Flat slabs that stack neatly for cooling.', image: _crushed, pack: '25 kg slab', weightKg: 25, price: 279, mrp: 310, rating: 4.3, uses: ['Cooling', 'Storage'], warning: _notForDrinks),
  Product(id: 'dry-1', name: 'Dry Ice', categoryId: 'dry', description: 'For fog effects and short-term frozen transport.', image: _dry, pack: '1 kg pack', weightKg: 1, price: 149, mrp: 170, rating: 4.6, uses: ['Fog effect', 'Frozen transport'], warning: _dryIceWarning, subscribable: false),
  Product(id: 'dry-5', name: 'Dry Ice', categoryId: 'dry', description: 'For frozen food transport and special cooling.', image: _dry, pack: '5 kg pack', weightKg: 5, price: 649, mrp: 720, rating: 4.5, uses: ['Frozen food transport', 'Special cooling'], warning: _dryIceWarning, subscribable: false),
  Product(id: 'box-20', name: 'Insulated Ice Box', categoryId: 'box', description: 'Keeps ice frozen for hours at picnics and parties.', image: _box, pack: '20 litre box', weightKg: 0, price: 899, mrp: 1100, rating: 4.4, uses: ['Picnics', 'Parties'], subscribable: false),
  Product(id: 'box-45', name: 'Insulated Ice Box', categoryId: 'box', description: 'A large box for events and long trips.', image: _box, pack: '45 litre box', weightKg: 0, price: 1599, mrp: 1900, rating: 4.5, uses: ['Events', 'Long trips'], subscribable: false, inStock: false),
];

Product? productById(String id) {
  for (final p in products) {
    if (p.id == id) return p;
  }
  return null;
}

IceCategory categoryById(String id) => categories.firstWhere((c) => c.id == id);

List<Product> productsIn(String categoryId) => products.where((p) => p.categoryId == categoryId).toList();

/// Case-insensitive search across names, descriptions and uses.
List<Product> searchProducts(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  return products
      .where((p) => '${p.name} ${p.pack} ${p.description} ${p.uses.join(' ')}'.toLowerCase().contains(q))
      .toList();
}

/// Goes up when the catalogue changes, so screens showing it redraw.
class CatalogVersion extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final catalogVersionProvider = NotifierProvider<CatalogVersion, int>(CatalogVersion.new);

/// Fetches products, coupons and charges, which the admin can change at any time.
final catalogSyncProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    if (useFakeBackend) return;
    final api = ref.read(apiProvider);
    products = (await api.get('/customer/products') as Object).mapped(Product.fromJson);
    AppConstants.applyServerConfig(await api.get('/customer/config') as Map<String, dynamic>);
    applyCoupons(await api.get('/customer/coupons') as List);
    ref.read(catalogVersionProvider.notifier).bump();
  };
});

class FavouritesController extends Notifier<Set<String>> {
  static const _key = 'favourites';

  @override
  Set<String> build() {
    final saved = ref.watch(customerStoreProvider).readMap(_key);
    return saved == null ? {} : (saved['ids'] as List).cast<String>().toSet();
  }

  void _save(Set<String> ids) {
    state = ids;
    ref.read(customerStoreProvider).writeMap(_key, {'ids': ids.toList()});
  }

  Future<void> refresh() async {
    if (useFakeBackend) return;
    _save(((await ref.read(apiProvider).get('/customer/favourites')) as List).cast<String>().toSet());
  }

  Future<void> toggle(String id) async {
    final on = !state.contains(id);
    final before = state;
    _save(on ? {...state, id} : ({...state}..remove(id)));
    if (useFakeBackend) return;
    try {
      await ref.read(apiProvider).put('/customer/favourites/$id', {'on': on});
    } catch (_) {
      _save(before);
      rethrow;
    }
  }
}

final favouritesProvider = NotifierProvider<FavouritesController, Set<String>>(FavouritesController.new);

/// What others said about a product. Without a server, these come from the device.
final productReviewsProvider = FutureProvider.family<List<Review>, String>((ref, productId) async {
  if (useFakeBackend) return ref.watch(reviewsProvider).where((r) => r.productId == productId).toList();
  return (await ref.read(apiProvider).get('/customer/products/$productId/reviews') as Object).mapped(Review.fromJson);
});

class ReviewsController extends ListStore<Review> {
  @override
  String get key => 'reviews';
  @override
  Review fromJson(Json json) => Review.fromJson(json);
  @override
  Json toJson(Review item) => item.toJson();

  @override
  List<Review> seed() {
    final now = DateTime.now();
    return [
      for (final p in products) ...[
        Review(productId: p.id, author: 'Rohan M.', rating: 5, text: 'Delivered on time and well packed.', at: now.subtract(const Duration(days: 3))),
        Review(productId: p.id, author: 'Sneha K.', rating: 4, text: 'Good quality. Delivery was a little late once.', at: now.subtract(const Duration(days: 12))),
      ],
    ];
  }

  void add(Review review) => save([review, ...state]);
}

final reviewsProvider = NotifierProvider<ReviewsController, List<Review>>(ReviewsController.new);
