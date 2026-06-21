enum ColumnFilterType {
  // String
  contains,
  startsWith,
  isNotEmpty,
  // Number
  equal,
  lessThan,
  greaterThan,
  // Date
  year,
}

class ColumnFilter {
  final String column;
  final ColumnFilterType type;
  final dynamic value;

  ColumnFilter({
    required this.column,
    required this.type,
    required this.value,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ColumnFilter &&
          runtimeType == other.runtimeType &&
          column == other.column &&
          type == other.type &&
          value == other.value;

  @override
  int get hashCode => column.hashCode ^ type.hashCode ^ value.hashCode;

  bool evaluate(dynamic recordValue) {
    if (recordValue == null) return false;

    switch (type) {
      case ColumnFilterType.contains:
        return recordValue.toString().toLowerCase().contains(value.toString().toLowerCase());
      case ColumnFilterType.startsWith:
        return recordValue.toString().toLowerCase().startsWith(value.toString().toLowerCase());
      case ColumnFilterType.isNotEmpty:
        return recordValue != null && recordValue.toString().trim().isNotEmpty;
      case ColumnFilterType.equal:
        final numValue = _numOrNull(recordValue);
        final targetNum = _numOrNull(value);
        if (numValue != null && targetNum != null) return numValue == targetNum;
        return recordValue.toString() == value.toString();
      case ColumnFilterType.lessThan:
        final numValue = _numOrNull(recordValue);
        final targetNum = _numOrNull(value);
        if (numValue != null && targetNum != null) return numValue < targetNum;
        return false;
      case ColumnFilterType.greaterThan:
        final numValue = _numOrNull(recordValue);
        final targetNum = _numOrNull(value);
        if (numValue != null && targetNum != null) return numValue > targetNum;
        return false;
      case ColumnFilterType.year:
        final targetYear = int.tryParse(value.toString());
        if (targetYear == null) return false;
        
        DateTime? dt;
        if (recordValue is int) {
          // Assume milliseconds since epoch
          dt = DateTime.fromMillisecondsSinceEpoch(recordValue);
        } else {
          dt = DateTime.tryParse(recordValue.toString());
        }
        
        if (dt != null) {
          return dt.year == targetYear;
        }
        return false;
    }
  }

  num? _numOrNull(dynamic val) {
    if (val is num) return val;
    if (val is String) return num.tryParse(val);
    return null;
  }
}
