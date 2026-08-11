import re

with open('lib/ui/Shared_Custom/requests_data_table_core.dart', 'r') as f:
    content = f.read()

state_replacement = """class _RequestsDataTableCoreState extends State<RequestsDataTableCore> {
  final Set<int> _selectedIds = {};
  int? _lastSelectedIndex;

  String? _sortKey;
  bool _sortAscending = true;
  late List<Map<String, dynamic>> _sortedRequests;

  @override
  void initState() {
    super.initState();
    _sortedRequests = List.from(widget.requests);
  }

  @override
  void didUpdateWidget(covariant RequestsDataTableCore oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requests != widget.requests) {
      _sortedRequests = List.from(widget.requests);
      _applySort();
    }
  }

  void _applySort() {
    if (_sortKey == null) return;
    _sortedRequests.sort((a, b) {
      dynamic valA;
      dynamic valB;
      
      if (_sortKey == 'id') {
        valA = int.tryParse(a['id']?.toString() ?? '0') ?? 0;
        valB = int.tryParse(b['id']?.toString() ?? '0') ?? 0;
      } else if (_sortKey == 'status') {
        valA = DocumentsLogic.cleanStatusName(a['status']?.toString() ?? '');
        valB = DocumentsLogic.cleanStatusName(b['status']?.toString() ?? '');
      } else if (_sortKey == 'situation') {
        valA = a['situation']?.toString() ?? '';
        valB = b['situation']?.toString() ?? '';
      } else if (_sortKey == 'category') {
        final catA = (a['original'] as Map?)?['R_Category_ID'];
        valA = catA is Map ? (catA['Name'] ?? catA['identifier'] ?? '') : '';
        final catB = (b['original'] as Map?)?['R_Category_ID'];
        valB = catB is Map ? (catB['Name'] ?? catB['identifier'] ?? '') : '';
      } else if (_sortKey == 'subject') {
        valA = a['emailSubject']?.toString() ?? (a['original'] as Map?)?['Summary']?.toString() ?? '';
        valB = b['emailSubject']?.toString() ?? (b['original'] as Map?)?['Summary']?.toString() ?? '';
      } else if (_sortKey == 'priority') {
        valA = a['level']?.toString() ?? '';
        valB = b['level']?.toString() ?? '';
      } else if (_sortKey == 'bp') {
        valA = a['bpName']?.toString() ?? '';
        valB = b['bpName']?.toString() ?? '';
      } else if (_sortKey == 'user') {
        valA = a['userName']?.toString() ?? '';
        valB = b['userName']?.toString() ?? '';
      } else if (_sortKey == 'salesRep') {
        valA = a['salesRepName']?.toString() ?? '';
        valB = b['salesRepName']?.toString() ?? '';
      } else if (_sortKey == 'description') {
        valA = a['descriptionClean']?.toString() ?? '';
        valB = b['descriptionClean']?.toString() ?? '';
      } else if (_sortKey == 'qtySpent') {
        valA = (a['qtySpent'] as num?)?.toDouble() ?? 0.0;
        valB = (b['qtySpent'] as num?)?.toDouble() ?? 0.0;
      } else if (_sortKey == 'productChip') {
        valA = a['productChipName']?.toString() ?? '';
        valB = b['productChipName']?.toString() ?? '';
      } else if (_sortKey == 'phase') {
        valA = a['phaseName']?.toString() ?? '';
        valB = b['phaseName']?.toString() ?? '';
      } else if (_sortKey == 'task') {
        valA = a['taskName']?.toString() ?? '';
        valB = b['taskName']?.toString() ?? '';
      }
      
      int cmp = 0;
      if (valA is num && valB is num) {
        cmp = valA.compareTo(valB);
      } else {
        cmp = valA.toString().compareTo(valB.toString());
      }
      return _sortAscending ? cmp : -cmp;
    });
  }

  void _onSort(String key) {
    setState(() {
      if (_sortKey == key) {
        _sortAscending = !_sortAscending;
      } else {
        _sortKey = key;
        _sortAscending = true;
      }
      _applySort();
    });
  }

  int _getRealId(Map<String, dynamic> req) => 
"""

content = content.replace("class _RequestsDataTableCoreState extends State<RequestsDataTableCore> {\n  final Set<int> _selectedIds = {};\n  int? _lastSelectedIndex;\n\n  int _getRealId(Map<String, dynamic> req) => ", state_replacement)

# Replace fixed columns
fixed_cols_old = """    final fixedCols = [
      const ResponsiveDataColumn(label: 'Acciones'),
      const ResponsiveDataColumn(label: 'Ticket'),
      if (!isLaptop) ...[
        const ResponsiveDataColumn(label: 'Estado'),
        if (AccessControl.isAdmin || AccessControl.isSupport) const ResponsiveDataColumn(label: 'Tipo de Solicitud'),
      ],
    ];"""

fixed_cols_new = """    final fixedCols = [
      const ResponsiveDataColumn(label: 'Acciones'),
      const ResponsiveDataColumn(label: 'Ticket', sortKey: 'id'),
      if (!isLaptop) ...[
        const ResponsiveDataColumn(label: 'Estado', sortKey: 'status'),
        if (AccessControl.isAdmin || AccessControl.isSupport) const ResponsiveDataColumn(label: 'Tipo de Solicitud', sortKey: 'situation'),
      ],
    ];"""

content = content.replace(fixed_cols_old, fixed_cols_new)

# Replace scrollable columns
scrollable_cols_old = """    final scrollableCols = [
      if (isLaptop) ...[
        const ResponsiveDataColumn(label: 'Estado'),
        if (AccessControl.isAdmin || AccessControl.isSupport) const ResponsiveDataColumn(label: 'Tipo de Solicitud'),
      ],
      const ResponsiveDataColumn(label: 'Categoría'),
      const ResponsiveDataColumn(label: 'Asunto'),
      const ResponsiveDataColumn(label: 'Prioridad'),
      if (widget.showProjectContext) const ResponsiveDataColumn(label: 'Fase'),
      if (widget.showProjectContext) const ResponsiveDataColumn(label: 'Tarea'),
      if (AccessControl.isAdmin) const ResponsiveDataColumn(label: 'Tercero'),
      if (AccessControl.isAdmin) const ResponsiveDataColumn(label: 'Usuario'),
      if (AccessControl.isAdmin) const ResponsiveDataColumn(label: 'Rep. Comercial'),
      const ResponsiveDataColumn(label: 'Descripción'),
      const ResponsiveDataColumn(label: 'Horas Consumidas'),
      if (!widget.showProjectContext) const ResponsiveDataColumn(label: 'Ficha de Producto'),
    ];"""

scrollable_cols_new = """    final scrollableCols = [
      if (isLaptop) ...[
        const ResponsiveDataColumn(label: 'Estado', sortKey: 'status'),
        if (AccessControl.isAdmin || AccessControl.isSupport) const ResponsiveDataColumn(label: 'Tipo de Solicitud', sortKey: 'situation'),
      ],
      const ResponsiveDataColumn(label: 'Categoría', sortKey: 'category'),
      const ResponsiveDataColumn(label: 'Asunto', sortKey: 'subject'),
      const ResponsiveDataColumn(label: 'Prioridad', sortKey: 'priority'),
      if (widget.showProjectContext) const ResponsiveDataColumn(label: 'Fase', sortKey: 'phase'),
      if (widget.showProjectContext) const ResponsiveDataColumn(label: 'Tarea', sortKey: 'task'),
      if (AccessControl.isAdmin) const ResponsiveDataColumn(label: 'Tercero', sortKey: 'bp'),
      if (AccessControl.isAdmin) const ResponsiveDataColumn(label: 'Usuario', sortKey: 'user'),
      if (AccessControl.isAdmin) const ResponsiveDataColumn(label: 'Rep. Comercial', sortKey: 'salesRep'),
      const ResponsiveDataColumn(label: 'Descripción', sortKey: 'description'),
      const ResponsiveDataColumn(label: 'Horas Consumidas', sortKey: 'qtySpent', numeric: true),
      if (!widget.showProjectContext) const ResponsiveDataColumn(label: 'Ficha de Producto', sortKey: 'productChip'),
    ];"""

content = content.replace(scrollable_cols_old, scrollable_cols_new)

# Replace items: widget.requests with _sortedRequests
content = content.replace("items: widget.requests,", "items: _sortedRequests,\n                sortKey: _sortKey,\n                sortAscending: _sortAscending,\n                onSort: _onSort,")

# Replace widget.requests mapped correctly in handlers
content = content.replace("widget.requests.map", "_sortedRequests.map")
content = content.replace("widget.requests.indexWhere", "_sortedRequests.indexWhere")
content = content.replace("widget.requests[i]", "_sortedRequests[i]")


with open('lib/ui/Shared_Custom/requests_data_table_core.dart', 'w') as f:
    f.write(content)

