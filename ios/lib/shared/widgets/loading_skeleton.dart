import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/colors.dart';

/// Скелетон загрузки с shimmer-эффектом
class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  /// Ширина скелетона (null = заполнить доступное пространство)
  final double? width;

  /// Высота скелетона
  final double height;

  /// Радиус скругления
  final double borderRadius;

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
        baseColor: AppColors.surfaceVariant,
        highlightColor: AppColors.surface,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      );
}

/// Скелетон карточки
class CardSkeleton extends StatelessWidget {
  const CardSkeleton({
    super.key,
    this.height = 120,
  });

  final double height;

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
        baseColor: AppColors.surfaceVariant,
        highlightColor: AppColors.surface,
        child: Container(
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
}

/// Скелетон списка
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 72,
  });

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) => ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: itemCount,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Avatar
              const LoadingSkeleton(
                width: 48,
                height: 48,
                borderRadius: 24,
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LoadingSkeleton(
                      width: MediaQuery.of(context).size.width * 0.5,
                      height: 16,
                    ),
                    const SizedBox(height: 8),
                    const LoadingSkeleton(
                      height: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// Скелетон детальной страницы
class DetailSkeleton extends StatelessWidget {
  const DetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header image
            const LoadingSkeleton(
              height: 200,
              borderRadius: 16,
            ),
            const SizedBox(height: 24),
            // Title
            const LoadingSkeleton(
              width: 200,
              height: 28,
            ),
            const SizedBox(height: 8),
            // Subtitle
            const LoadingSkeleton(
              width: 150,
              height: 16,
            ),
            const SizedBox(height: 24),
            // Content lines
            for (int i = 0; i < 5; i++) ...[
              const LoadingSkeleton(height: 14),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 16),
            // Stats row
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatSkeleton(),
                _StatSkeleton(),
                _StatSkeleton(),
              ],
            ),
          ],
        ),
      );
}

class _StatSkeleton extends StatelessWidget {
  const _StatSkeleton();

  @override
  Widget build(BuildContext context) => const Column(
        children: [
          LoadingSkeleton(
            width: 40,
            height: 40,
            borderRadius: 20,
          ),
          SizedBox(height: 8),
          LoadingSkeleton(
            width: 60,
            height: 12,
          ),
        ],
      );
}
