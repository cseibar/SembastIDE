import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';
import '../home_view_model.dart';
import '../record_editor_dialog.dart';
import 'column_filter_dialog.dart';

class RecordsTable extends ConsumerStatefulWidget {
  final List<RecordSnapshot<dynamic, dynamic>> records;

  const RecordsTable({super.key, required this.records});

  @override
  ConsumerState<RecordsTable> createState() => _RecordsTableState();
}

class _RecordsTableState extends ConsumerState<RecordsTable> {
  late List<String> _columns;
  bool _anyNonMap = false;
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _extractColumns();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RecordsTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.records != widget.records) {
      _extractColumns();
    }
  }

  void _extractColumns() {
    final keys = <String>{};
    _anyNonMap = false;
    for (var record in widget.records) {
      if (record.value is Map) {
        for (var key in (record.value as Map).keys) {
          keys.add(key.toString());
        }
      } else {
        _anyNonMap = true;
      }
    }
    _columns = keys.toList()..sort();
  }

  void _showEditor(BuildContext context, dynamic key, dynamic value) {
    showDialog(
      context: context,
      builder: (context) {
        return RecordEditorDialog(
          recordKey: key,
          initialValue: value,
          onSave: (newKey, newValue) async {
            final viewModel = ref.read(homeViewModelProvider.notifier);
            if (key == null) {
              await viewModel.addRecord(newValue);
            } else {
              await viewModel.updateRecord(key, newValue);
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeViewModelProvider);
    final viewModel = ref.read(homeViewModelProvider.notifier);


    int? sortColumnIndex;
    if (state.sortColumn == 'Key') {
      sortColumnIndex = 0;
    } else if (state.sortColumn != null) {
      final idx = _columns.indexOf(state.sortColumn!);
      if (idx >= 0) {
        sortColumnIndex = idx + 1;
      }
    }

    final usePagination = widget.records.length > 500;

    Widget tableWidget;
    if (usePagination) {
      tableWidget = PaginatedDataTable(
        sortColumnIndex: sortColumnIndex,
        sortAscending: state.sortAscending,
        columns: _buildColumns(state, viewModel),
        source: _RecordDataSource(
          records: widget.records,
          columns: _columns,
          anyNonMap: _anyNonMap,
          onEdit: (key, value) => _showEditor(context, key, value),
          onDelete: (key) async {
            await ref.read(homeViewModelProvider.notifier).deleteRecord(key);
          },
        ),
        rowsPerPage: 20,
        showCheckboxColumn: false,
      );
    } else {
      final source = _RecordDataSource(
        records: widget.records,
        columns: _columns,
        anyNonMap: _anyNonMap,
        onEdit: (key, value) => _showEditor(context, key, value),
        onDelete: (key) async {
          await ref.read(homeViewModelProvider.notifier).deleteRecord(key);
        },
      );
      tableWidget = DataTable(
        sortColumnIndex: sortColumnIndex,
        sortAscending: state.sortAscending,
        columns: _buildColumns(state, viewModel),
        rows: List.generate(widget.records.length, (index) => source.getRow(index)!),
        showCheckboxColumn: false,
      );
    }

    return Scrollbar(
      controller: _verticalScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalScrollController,
        scrollDirection: Axis.vertical,
        child: Scrollbar(
          controller: _horizontalScrollController,
          thumbVisibility: true,
          notificationPredicate: (notif) => notif.depth == 0,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: tableWidget,
          ),
        ),
      ),
    );
  }

  List<DataColumn> _buildColumns(HomeState state, HomeViewModel viewModel) {
    void showFilter(String colName) {
      final existingFilter = state.columnFilters.where((f) => f.column == colName).firstOrNull;
      showDialog(
        context: context,
        builder: (ctx) => ColumnFilterDialog(
          columnName: colName,
          initialFilter: existingFilter,
          onApply: (filter) {
            if (filter == null) {
              viewModel.removeColumnFilter(colName);
            } else {
              viewModel.setColumnFilter(filter);
            }
          },
        ),
      );
    }

    final cols = [
      DataColumn(
        label: const Text('Key', style: TextStyle(fontWeight: FontWeight.bold)),
        onSort: (columnIndex, ascending) => viewModel.setSortColumn('Key'),
      ),
    ];
    
    for (var col in _columns) {
      final isFiltered = state.columnFilters.any((f) => f.column == col);
      cols.add(DataColumn(
        onSort: (columnIndex, ascending) => viewModel.setSortColumn(col),
        label: GestureDetector(
          onSecondaryTapDown: (_) => showFilter(col),
          onLongPress: () => showFilter(col),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(col, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (isFiltered) ...[
                const SizedBox(width: 4),
                const Icon(Icons.filter_alt, size: 14, color: Colors.blue),
              ]
            ],
          ),
        ),
      ));
    }
    
    // Fallback column if there are non-map values
    if (_anyNonMap) {
      cols.add(const DataColumn(label: Text('Value', style: TextStyle(fontWeight: FontWeight.bold))));
    }
    
    // Actions column
    cols.add(const DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))));
    
    return cols;
  }
}

class _RecordDataSource extends DataTableSource {
  final List<RecordSnapshot<dynamic, dynamic>> records;
  final List<String> columns;
  final bool anyNonMap;
  final Function(dynamic key, dynamic value) onEdit;
  final Function(dynamic key) onDelete;

  _RecordDataSource({
    required this.records,
    required this.columns,
    required this.anyNonMap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= records.length) return null;
    final record = records[index];
    final isMap = record.value is Map;
    final mapValue = isMap ? (record.value as Map) : null;

    final cells = <DataCell>[
      DataCell(Text(record.key.toString())),
    ];

    for (var col in columns) {
      if (isMap) {
        // Check for string key first, then fallback to other types if possible, though our columns are strings
        final val = mapValue![col];
        if (val != null || mapValue.containsKey(col)) {
          cells.add(DataCell(_buildCellText(val)));
        } else {
          cells.add(const DataCell(Text('-')));
        }
      } else {
        cells.add(const DataCell(Text('-')));
      }
    }

    if (anyNonMap) {
      if (!isMap) {
        cells.add(DataCell(_buildCellText(record.value)));
      } else {
        cells.add(const DataCell(Text('-')));
      }
    }

    cells.add(DataCell(Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
          onPressed: () => onEdit(record.key, record.value),
          tooltip: 'Edit',
        ),
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
          onPressed: () => onDelete(record.key),
          tooltip: 'Delete',
        ),
      ],
    )));

    return DataRow(cells: cells);
  }

  Widget _buildCellText(dynamic value) {
    String strValue;
    try {
      if (value is Map || value is List) {
        strValue = jsonEncode(value, toEncodable: (nonEncodable) => nonEncodable.toString());
      } else {
        strValue = value?.toString() ?? 'null';
      }
    } catch (e) {
      strValue = value?.toString() ?? 'Error';
    }
    
    // Truncate if too long to prevent massive rows
    if (strValue.length > 100) {
      strValue = '${strValue.substring(0, 100)}...';
    }
    
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Tooltip(
        message: strValue.length > 50 ? strValue : '',
        child: Text(
          strValue,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => records.length;

  @override
  int get selectedRowCount => 0;
}
