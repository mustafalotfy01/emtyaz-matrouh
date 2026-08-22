import 'package:flutter/material.dart';
import '../theme/app_design_tokens.dart';

class AppTableColumn {
  final String label;
  final double? width;
  final int? flex;
  final TextAlign alignment;
  final bool isSortable;

  const AppTableColumn({
    required this.label,
    this.width,
    this.flex = 1,
    this.alignment = TextAlign.start,
    this.isSortable = false,
  });
}

class AppTable extends StatelessWidget {
  final List<AppTableColumn> columns;
  final int itemCount;
  final List<Widget> Function(BuildContext context, int index) rowBuilder;
  final VoidCallback? onRowTap;
  final int? sortColumnIndex;
  final bool isAscending;
  final Function(int columnIndex)? onSort;
  final Widget? emptyState;
  final bool isLoading;

  const AppTable({
    super.key,
    required this.columns,
    required this.itemCount,
    required this.rowBuilder,
    this.onRowTap,
    this.sortColumnIndex,
    this.isAscending = true,
    this.onSort,
    this.emptyState,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppDesignTokens.isDark(context);

    if (isLoading) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppDesignTokens.surface(context),
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusLg),
          border: Border.all(color: AppDesignTokens.border(context)),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppDesignTokens.primary),
        ),
      );
    }

    if (itemCount == 0 && emptyState != null) {
      return emptyState!;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppDesignTokens.surface(context),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusLg),
        border: Border.all(color: AppDesignTokens.border(context)),
        boxShadow: AppDesignTokens.cardShadow(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppDesignTokens.surfaceElevatedDark
                  : AppDesignTokens.surfaceMutedLight,
              border: Border(
                bottom: BorderSide(color: AppDesignTokens.border(context)),
              ),
            ),
            child: Row(
              children: columns.asMap().entries.map((entry) {
                final idx = entry.key;
                final col = entry.value;

                final headerWidget = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      col.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: AppDesignTokens.textSecondary(context),
                      ),
                    ),
                    if (col.isSortable && onSort != null) ...[
                      const SizedBox(width: 4),
                      Icon(
                        sortColumnIndex == idx
                            ? (isAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                            : Icons.unfold_more_rounded,
                        size: 14,
                        color: sortColumnIndex == idx
                            ? AppDesignTokens.primary
                            : AppDesignTokens.textMuted(context),
                      ),
                    ],
                  ],
                );

                if (col.width != null) {
                  return SizedBox(
                    width: col.width,
                    child: col.isSortable && onSort != null
                        ? InkWell(
                            onTap: () => onSort!(idx),
                            child: headerWidget,
                          )
                        : headerWidget,
                  );
                }

                return Expanded(
                  flex: col.flex ?? 1,
                  child: col.isSortable && onSort != null
                      ? InkWell(
                          onTap: () => onSort!(idx),
                          child: headerWidget,
                        )
                      : headerWidget,
                );
              }).toList(),
            ),
          ),

          // Body Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: itemCount,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              thickness: 1,
              color: AppDesignTokens.borderSubtle(context),
            ),
            itemBuilder: (context, index) {
              final cells = rowBuilder(context, index);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: cells.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final cell = entry.value;
                    final col = idx < columns.length ? columns[idx] : null;

                    if (col?.width != null) {
                      return SizedBox(width: col!.width, child: cell);
                    }
                    return Expanded(
                      flex: col?.flex ?? 1,
                      child: cell,
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
