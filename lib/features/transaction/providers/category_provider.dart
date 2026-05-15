import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
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

  // ── Read helpers ───────────────────────────────────────────────────────────

  List<CategoryModel> mainCategories({String? type}) {
    return state.where((c) {
      final isMain = c.parentId == null;
      if (type == null) return isMain;
      return isMain && (c.type == type || c.type == 'both');
    }).toList();
  }

  List<CategoryModel> subCategories(String parentId) {
    return state.where((c) => c.parentId == parentId).toList();
  }

  List<CategoryModel> get parents =>
      state.where((c) => c.parentId == null).toList();

  List<CategoryModel> subsOf(String parentId) =>
      state.where((c) => c.parentId == parentId).toList();

  CategoryModel? findById(String id) {
    try {
      return state.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  int transactionCountFor(String categoryId) =>
      HiveService.transactions.values
          .where((t) => t.categoryId == categoryId)
          .length;

  // ── CRUD (user categories only) ────────────────────────────────────────────

  Future<void> addCategory({
    required String name,
    required String icon,
    required String color,
    required String type,
    String? parentId,
  }) async {
    final id = 'user_${const Uuid().v4()}';
    await HiveService.categories.put(
      id,
      CategoryModel(
        id: id,
        name: name,
        icon: icon,
        color: color,
        parentId: parentId,
        type: type,
        isDefault: false,
      ),
    );
    _load();
  }

  Future<void> updateCategory({
    required String id,
    required String name,
    required String icon,
    required String color,
    required String type,
  }) async {
    final cat = HiveService.categories.get(id);
    if (cat == null || cat.isDefault) return;
    cat.name = name;
    cat.icon = icon;
    cat.color = color;
    cat.type = type;
    await cat.save();
    _load();
  }

  Future<void> deleteCategory(String id) async {
    final cat = HiveService.categories.get(id);
    if (cat == null || cat.isDefault) return;
    if (cat.parentId == null) {
      final subs =
          state.where((c) => c.parentId == id && !c.isDefault).toList();
      for (final sub in subs) {
        await HiveService.categories.delete(sub.id);
      }
    }
    await HiveService.categories.delete(id);
    _load();
  }
}
