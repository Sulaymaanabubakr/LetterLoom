import 'package:flutter/foundation.dart';

@immutable
class CosmeticItem {
  final String id;
  final String title;
  final String category; // 'board', 'tile', 'frame'
  final String unlockRequirement;
  final bool isUnlocked;

  const CosmeticItem({
    required this.id,
    required this.title,
    required this.category,
    required this.unlockRequirement,
    this.isUnlocked = false,
  });

  CosmeticItem copyWith({bool? isUnlocked}) {
    return CosmeticItem(
      id: id,
      title: title,
      category: category,
      unlockRequirement: unlockRequirement,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }
}

class CosmeticsService {
  static const List<CosmeticItem> allCosmetics = [
    CosmeticItem(id: 'board_classic', title: 'Classic Emerald', category: 'board', unlockRequirement: 'Unlocked by default', isUnlocked: true),
    CosmeticItem(id: 'board_obsidian', title: 'Obsidian Gold', category: 'board', unlockRequirement: 'Reach Level 5', isUnlocked: false),
    CosmeticItem(id: 'board_velvet', title: 'Royal Velvet', category: 'board', unlockRequirement: 'Reach Level 10', isUnlocked: false),
    CosmeticItem(id: 'tile_ivory', title: 'Classic Ivory', category: 'tile', unlockRequirement: 'Unlocked by default', isUnlocked: true),
    CosmeticItem(id: 'tile_mahogany', title: 'Rich Mahogany', category: 'tile', unlockRequirement: 'Reach Level 3', isUnlocked: false),
    CosmeticItem(id: 'tile_gold', title: 'Polished Gold', category: 'tile', unlockRequirement: 'Reach Level 15', isUnlocked: false),
  ];
}
