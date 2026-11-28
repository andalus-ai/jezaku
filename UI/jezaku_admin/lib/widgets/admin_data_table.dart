import 'package:flutter/material.dart';

import 'admin_feedback_state.dart';

class AdminTableColumn<T> {
  const AdminTableColumn({
    required this.label,
    required this.cellBuilder,
    this.compare,
    this.numeric = false,
  });

  final String label;
  final Widget Function(BuildContext context, T row) cellBuilder;
  final int Function(T a, T b)? compare;
  final bool numeric;
}

class AdminDataTable<T> extends StatefulWidget {
  const AdminDataTable({
    required this.items,
    required this.columns,
    required this.searchText,
    required this.mobileCardBuilder,
    this.searchHint = 'Search records',
    this.filterBar,
    this.pageSize = 10,
    this.loading = false,
    this.errorMessage,
    this.onRetry,
    this.emptyTitle = 'No records found',
    this.emptyMessage = 'Try changing your search or filters.',
    this.onRowTap,
    super.key,
  }) : assert(pageSize > 0);

  final List<T> items;
  final List<AdminTableColumn<T>> columns;
  final String Function(T row) searchText;
  final Widget Function(BuildContext context, T row) mobileCardBuilder;
  final String searchHint;
  final Widget? filterBar;
  final int pageSize;
  final bool loading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final String emptyTitle;
  final String emptyMessage;
  final ValueChanged<T>? onRowTap;

  @override
  State<AdminDataTable<T>> createState() => _AdminDataTableState<T>();
}

class _AdminDataTableState<T> extends State<AdminDataTable<T>> {
  final _searchController = TextEditingController();
  int _page = 0;
  int? _sortColumn;
  bool _ascending = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<T> get _visibleItems {
    final query = _searchController.text.trim().toLowerCase();
    final result = widget.items.where((item) => query.isEmpty || widget.searchText(item).toLowerCase().contains(query)).toList();
    final sortIndex = _sortColumn;
    if (sortIndex != null) {
      final compare = widget.columns[sortIndex].compare;
      if (compare != null) {
        result.sort((a, b) {
          final value = compare(a, b);
          return _ascending ? value : -value;
        });
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) return const AdminFeedbackState(kind: AdminFeedbackKind.loading);
    if (widget.errorMessage != null) {
      return AdminFeedbackState(kind: AdminFeedbackKind.error, message: widget.errorMessage, onRetry: widget.onRetry);
    }

    final items = _visibleItems;
    final pageCount = (items.length / widget.pageSize).ceil();
    final currentPage = pageCount == 0 ? 0 : _page.clamp(0, pageCount - 1);
    final start = currentPage * widget.pageSize;
    final pageItems = items.skip(start).take(widget.pageSize).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: compact ? constraints.maxWidth : 320,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() => _page = 0),
                    decoration: InputDecoration(
                      hintText: widget.searchHint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty ? null : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () { _searchController.clear(); setState(() => _page = 0); },
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ),
                ),
                if (widget.filterBar != null) widget.filterBar!,
              ],
            ),
            const SizedBox(height: 14),
            if (items.isEmpty)
              Expanded(child: AdminFeedbackState(kind: AdminFeedbackKind.empty, title: widget.emptyTitle, message: widget.emptyMessage))
            else ...[
              Expanded(
                child: compact
                    ? ListView.separated(
                        itemCount: pageItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = pageItems[index];
                          return Material(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: widget.onRowTap == null ? null : () => widget.onRowTap!(item),
                              child: widget.mobileCardBuilder(context, item),
                            ),
                          );
                        },
                      )
                    : SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            sortColumnIndex: _sortColumn,
                            sortAscending: _ascending,
                            columns: [
                              for (var i = 0; i < widget.columns.length; i++)
                                DataColumn(
                                  label: Text(widget.columns[i].label),
                                  numeric: widget.columns[i].numeric,
                                  onSort: widget.columns[i].compare == null ? null : (_, ascending) => setState(() {
                                    _sortColumn = i;
                                    _ascending = ascending;
                                  }),
                                ),
                            ],
                            rows: [
                              for (final item in pageItems)
                                DataRow(
                                  onSelectChanged: widget.onRowTap == null ? null : (_) => widget.onRowTap!(item),
                                  cells: [for (final column in widget.columns) DataCell(column.cellBuilder(context, item))],
                                ),
                            ],
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('\${start + 1}–\${start + pageItems.length} of \${items.length}', style: Theme.of(context).textTheme.bodySmall),
                  const Spacer(),
                  IconButton(tooltip: 'Previous page', onPressed: currentPage == 0 ? null : () => setState(() => _page = currentPage - 1), icon: const Icon(Icons.chevron_left)),
                  Text('\${currentPage + 1} / $pageCount'),
                  IconButton(tooltip: 'Next page', onPressed: currentPage + 1 >= pageCount ? null : () => setState(() => _page = currentPage + 1), icon: const Icon(Icons.chevron_right)),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
