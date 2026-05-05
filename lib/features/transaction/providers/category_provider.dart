import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/hive/hive_service.dart';
import '../../../core/hive/models/category_model.dart';

final categoryProvider =
    StateNotifierProvider<CategoryNotifier, List<CategoryModel>>((ref) {
  return CategoryNotifier();
});

class CategoryNotifier extends StateNotifier<List<CategoryModel>> {
  CategoryNotifier() : super([]) {
    _load();
  }

  void _load() {
    state = HiveService.categories.values.toList();
  }

  // Semua kategori utama (parentId == null)
  List<CategoryModel> mainCategories({String? type}) {
    return state.where((c) {
      final isMain = c.parentId == null;
      if (type == null) return isMain;
      return isMain && (c.type == type || c.type == 'both');
    }).toList();
  }

  // Subkategori dari parentId tertentu
  List<CategoryModel> subCategories(String parentId) {
    return state.where((c) => c.parentId == parentId).toList();
  }

  // Cari kategori by id
  CategoryModel? findById(String id) {
    try {
      return state.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
