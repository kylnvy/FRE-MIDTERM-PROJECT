// STRAY-SAFE Analytics (Flutter) - themed like the STRAY-SAFE web app.
// FRE413 Final Project: enhanced analytics dashboard.
//
// Dashboard components (per the FRE413 final project guidelines):
//   1. KPI cards         - 6 cards computed from the filtered report data
//   2. Graphs            - status donut, reports-by-subdivision bar, monthly line
//   3. Key findings      - plain-language insights computed from the data
//   4. Records           - sortable table of the reports behind the KPIs/charts
//   5. Search/Filter/Sort- search box, priority + status + subdivision filters,
//                          sort-by control (also clickable table headers)
//   6. Pagination        - rows-per-page selector + page buttons
//
// Data source: assets/reports.csv
//   header: id,animal,location,priority,status,reported_at,resolved_at
//   animal   = Dog / Cat        location = subdivision name
//   priority = High / Medium / Low (assigned by the system)
//   status   = Pending, Endorsed, Escalated, Dispatched, Resolved,
//              Rejected, Deceased, Disputed or Archived
//
// pubspec.yaml needs:
//   dependencies:
//     fl_chart: ^0.69.0
//   flutter:
//     assets:
//       - assets/reports.csv
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:fl_chart/fl_chart.dart';

// ---------- Theme (matches the web app) ----------
const kOrange = Color(0xFFF97316);
const kAmber = Color(0xFFF59E0B);
const kBg = Color(0xFFF7F5F2);
const kInk = Color(0xFF1F2937);
const kMuted = Color(0xFF6B7280);
const kBlue = Color(0xFF2563EB);
const kGreen = Color(0xFF16A34A);
const kPurple = Color(0xFF7C3AED);
const kTeal = Color(0xFF0D9488);
const kRed = Color(0xFFE11D48);
const kBorder = Color(0xFFE5E7EB);

Color statusColor(String s) {
  switch (s.toLowerCase()) {
    case 'pending':
      return kOrange;
    case 'endorsed':
      return kBlue;
    case 'escalated':
      return kPurple;
    case 'dispatched':
      return kTeal;
    case 'resolved':
    case 'rescued':
    case 'adopted':
      return kGreen;
    case 'rejected':
      return kRed;
    default:
      return kMuted;
  }
}

Color priorityColor(String p) {
  switch (p.toLowerCase()) {
    case 'high':
      return kRed;
    case 'medium':
      return kAmber;
    case 'low':
      return kGreen;
    default:
      return kMuted;
  }
}

/// Sort rank for priorities (High first).
int priorityRank(String p) {
  const order = ['high', 'medium', 'low'];
  final i = order.indexOf(p.toLowerCase());
  return i < 0 ? order.length : i;
}

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String fmtDate(DateTime d) => '${_monthNames[d.month - 1]} ${d.day}, ${d.year}';

String fmtMonth(DateTime d) =>
    '${_monthNames[d.month - 1]} ${d.year.toString().substring(2)}';

// ---------- Data ----------
class Report {
  final String id, animal, location, priority, status;
  final DateTime reportedAt;
  final DateTime? resolvedAt;
  Report(this.id, this.animal, this.location, this.priority, this.status,
      this.reportedAt, this.resolvedAt);

  // Workflow (from the thesis): Pending -> Endorsed/Escalated -> Dispatched
  // -> Resolved. Other outcomes: Rejected, Deceased, Disputed, Archived.
  bool get isResolved =>
      const ['resolved', 'rescued', 'adopted'].contains(status.toLowerCase());
  bool get isRejected => status.toLowerCase() == 'rejected';
  bool get isHigh => priority.toLowerCase() == 'high';
  bool get isClosed => const [
        'resolved', 'rescued', 'adopted', 'deceased',
        'rejected', 'disputed', 'archived'
      ].contains(status.toLowerCase());
  double? get responseHours => resolvedAt == null
      ? null
      : resolvedAt!.difference(reportedAt).inMinutes / 60;
}

/// Reads the exported STRAY-SAFE reports from assets/reports.csv
Future<List<Report>> loadReports() async {
  final raw = await rootBundle.loadString('assets/reports.csv');
  final lines = raw
      .split(RegExp(r'\r?\n'))
      .skip(1)
      .where((l) => l.trim().isNotEmpty);
  final out = <Report>[];
  for (final l in lines) {
    final c = l.split(',').map((e) => e.trim()).toList();
    if (c.length < 6) continue; // skip malformed rows
    out.add(Report(c[0], c[1], c[2], c[3], c[4], DateTime.parse(c[5]),
        c.length > 6 && c[6].isNotEmpty ? DateTime.parse(c[6]) : null));
  }
  return out;
}

void main() => runApp(const StraySafeApp());

class StraySafeApp extends StatelessWidget {
  const StraySafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'STRAY-SAFE Analytics',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: kOrange,
        scaffoldBackgroundColor: kBg,
      ),
      home: FutureBuilder<List<Report>>(
        future: loadReports(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Scaffold(body: Center(child: Text('Error: ${snap.error}')));
          }
          if (!snap.hasData) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator(color: kOrange)));
          }
          return AnalyticsScreen(reports: snap.data!);
        },
      ),
    );
  }
}

// ---------- Sorting ----------
/// Columns of the records table (the index doubles as the sort key).
const _columns = [
  'ID', 'Animal', 'Subdivision', 'Priority', 'Status',
  'Reported', 'Resolved', 'Response'
];

int _compareBy(Report a, Report b, int col) {
  int nullable<T extends Comparable>(T? x, T? y) {
    if (x == null && y == null) return 0;
    if (x == null) return -1;
    if (y == null) return 1;
    return x.compareTo(y);
  }

  switch (col) {
    case 0:
      return a.id.compareTo(b.id);
    case 1:
      return a.animal.compareTo(b.animal);
    case 2:
      return a.location.compareTo(b.location);
    case 3:
      return priorityRank(a.priority).compareTo(priorityRank(b.priority));
    case 4:
      return a.status.compareTo(b.status);
    case 5:
      return a.reportedAt.compareTo(b.reportedAt);
    case 6:
      return nullable<DateTime>(a.resolvedAt, b.resolvedAt);
    case 7:
      return nullable<num>(a.responseHours, b.responseHours);
    default:
      return 0;
  }
}

// ---------- Dashboard page ----------
/// One filtered list of reports drives everything on the page: the KPI cards,
/// the charts, the key findings and the records table.
class AnalyticsScreen extends StatefulWidget {
  final List<Report> reports;
  const AnalyticsScreen({super.key, required this.reports});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static const _pageSizes = [5, 10, 25, 50];

  final _searchCtl = TextEditingController();
  String _query = '';
  String _priority = 'All';
  String _status = 'All';
  String _area = 'All';
  int _sortCol = 5; // Reported
  bool _asc = false; // newest first
  int _page = 0;
  int _pageSize = 5;

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  /// Applies a state change and returns to the first page of records.
  void _update(VoidCallback change) => setState(() {
        change();
        _page = 0;
      });

  bool get _hasFilters =>
      _query.trim().isNotEmpty ||
      _priority != 'All' ||
      _status != 'All' ||
      _area != 'All';

  void _clearFilters() {
    _searchCtl.clear();
    _update(() {
      _query = '';
      _priority = 'All';
      _status = 'All';
      _area = 'All';
    });
  }

  List<Report> _filtered() {
    final q = _query.trim().toLowerCase();
    return widget.reports.where((r) {
      if (_priority != 'All' && r.priority != _priority) return false;
      if (_status != 'All' && r.status != _status) return false;
      if (_area != 'All' && r.location != _area) return false;
      if (q.isEmpty) return true;
      final hay = [
        r.id,
        r.animal,
        r.location,
        r.priority,
        r.status,
        fmtDate(r.reportedAt),
        if (r.resolvedAt != null) fmtDate(r.resolvedAt!),
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  List<Report> _sorted(List<Report> list) {
    final out = [...list];
    out.sort((a, b) {
      final c = _compareBy(a, b, _sortCol);
      final r = c != 0 ? c : a.id.compareTo(b.id);
      return _asc ? r : -r;
    });
    return out;
  }

  PreferredSizeWidget _appBar() => AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        title: Row(children: [
          const Icon(Icons.pets, color: kOrange),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('SUBDIVISION ANALYTICS',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: kInk)),
                  Text('STRAY-SAFE  •  SMART STRAY ANIMAL REPORTING',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 9, letterSpacing: 0.6, color: kMuted)),
                ]),
          ),
        ]),
      );

  Widget _banner() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFFFEDD5), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFFEDD5)),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Here's what's happening",
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: kInk)),
                  const SizedBox(height: 4),
                  Text(
                      'Summary of stray animal reports in your subdivision  •  '
                      'source: assets/reports.csv (${widget.reports.length} records)',
                      style: const TextStyle(fontSize: 12, color: kMuted)),
                ]),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: const Text('Safer Neighborhoods\nStronger Communities',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w700,
                    color: kOrange)),
          ),
        ]),
      );

  // ---------- Search / filter controls ----------
  Widget _dropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T> onChanged,
    String? tooltip,
  }) {
    final box = Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: kInk),
          items: items,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
    return tooltip == null ? box : Tooltip(message: tooltip, child: box);
  }

  List<DropdownMenuItem<String>> _filterItems(
      String allLabel, Iterable<String> options) {
    return [
      DropdownMenuItem(value: 'All', child: Text(allLabel)),
      for (final o in options) DropdownMenuItem(value: o, child: Text(o)),
    ];
  }

  Widget _pill(String label, int count, Color? dot) {
    final sel = _priority == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => _update(() => _priority = label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? kOrange : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sel ? kOrange : kBorder),
          ),
          child: Row(children: [
            if (dot != null && !sel) ...[
              Icon(Icons.circle, size: 9, color: dot),
              const SizedBox(width: 6),
            ],
            Text('$label ($count)',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: sel ? Colors.white : kInk)),
          ]),
        ),
      ),
    );
  }

  Widget _filterPanel() {
    final all = widget.reports;
    final priorities = all.map((r) => r.priority).toSet().toList()
      ..sort((a, b) => priorityRank(a).compareTo(priorityRank(b)));
    final statuses = all.map((r) => r.status).toSet().toList()..sort();
    final areas = all.map((r) => r.location).toSet().toList()..sort();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 300,
            height: 44,
            child: TextField(
              controller: _searchCtl,
              onChanged: (v) => _update(() => _query = v),
              style: const TextStyle(fontSize: 13),
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search ID, animal, subdivision, status...',
                hintStyle: const TextStyle(fontSize: 13, color: kMuted),
                prefixIcon: const Icon(Icons.search, size: 20, color: kMuted),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchCtl.clear();
                          _update(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.zero,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kOrange, width: 1.5),
                ),
              ),
            ),
          ),
          _dropdown<String>(
            value: _status,
            tooltip: 'Filter by status',
            items: _filterItems('All statuses', statuses),
            onChanged: (v) => _update(() => _status = v),
          ),
          _dropdown<String>(
            value: _area,
            tooltip: 'Filter by subdivision',
            items: _filterItems('All subdivisions', areas),
            onChanged: (v) => _update(() => _area = v),
          ),
          if (_hasFilters)
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text('Clear filters'),
              style: TextButton.styleFrom(foregroundColor: kOrange),
            ),
        ],
      ),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _pill('All', all.length, null),
          for (final p in priorities)
            _pill(p, all.where((r) => r.priority == p).length,
                priorityColor(p)),
        ]),
      ),
    ]);
  }

  // ---------- KPI cards ----------
  Widget _kpiGrid(List<Report> rs, List<_MonthCount> months) {
    final total = rs.length;
    final done = rs.where((r) => r.isResolved).length;
    final rate = done / total * 100;
    final active = rs.where((r) => !r.isClosed).length;
    final rejected = rs.where((r) => r.isRejected).length;
    final high = rs.where((r) => r.isHigh).length;
    final highOpen = rs.where((r) => r.isHigh && !r.isClosed).length;
    final hrs = rs
        .where((r) => r.isResolved)
        .map((r) => r.responseHours)
        .whereType<double>()
        .toList();
    final avgHrs =
        hrs.isEmpty ? null : hrs.reduce((a, b) => a + b) / hrs.length;
    final latest = months.last;

    final cards = [
      _Kpi('TOTAL REPORTS', 'All submitted reports', '$total',
          Icons.description_outlined, kOrange,
          '${latest.count} in ${fmtMonth(latest.month)}'),
      _Kpi('ACTIVE CASES', 'Awaiting action', '$active', Icons.pending_actions,
          kBlue, '${(active / total * 100).toStringAsFixed(0)}% not yet closed'),
      _Kpi('RESOLUTION RATE', 'Closed as resolved',
          '${rate.toStringAsFixed(0)}%', Icons.verified_outlined, kGreen,
          '$done of $total resolved'),
      _Kpi('HIGH PRIORITY', 'System-flagged urgent', '$high', Icons.priority_high,
          kRed, '$highOpen still open'),
      _Kpi(
          'AVG RESPONSE',
          'Resolved cases only',
          avgHrs == null ? 'N/A' : '${avgHrs.toStringAsFixed(1)}h',
          Icons.timer_outlined,
          kPurple,
          'report to resolution'),
      _Kpi('REJECTED', 'Invalid or false', '$rejected',
          Icons.report_off_outlined, kTeal,
          '${(rejected / total * 100).toStringAsFixed(0)}% of reports'),
    ];

    return LayoutBuilder(builder: (context, box) {
      final cols = box.maxWidth >= 1000 ? 6 : (box.maxWidth >= 640 ? 3 : 2);
      return GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisExtent: 148,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12),
        children: cards,
      );
    });
  }

  // ---------- Key findings (computed) ----------
  List<String> _findings(List<Report> rs, List<_MonthCount> months) {
    final out = <String>[];
    final byArea = <String, int>{};
    for (final r in rs) {
      byArea[r.location] = (byArea[r.location] ?? 0) + 1;
    }
    final top = byArea.entries.reduce((a, b) => b.value > a.value ? b : a);
    out.add('${top.key} has the most reports: ${top.value} of ${rs.length} '
        '(${(top.value / rs.length * 100).toStringAsFixed(0)}%).');

    final high = rs.where((r) => r.isHigh).length;
    final highOpen = rs.where((r) => r.isHigh && !r.isClosed).length;
    if (high > 0) {
      out.add('High-priority cases are ${(high / rs.length * 100).toStringAsFixed(0)}% '
          'of reports; $highOpen of $high are still open.');
    }

    final resolved = rs.where((r) => r.isResolved && r.responseHours != null)
        .toList()
      ..sort((a, b) => a.responseHours!.compareTo(b.responseHours!));
    if (resolved.isNotEmpty) {
      final f = resolved.first, s = resolved.last;
      out.add('Fastest resolution: ${f.id} in ${f.responseHours!.toStringAsFixed(1)}h; '
          'slowest: ${s.id} in ${s.responseHours!.toStringAsFixed(1)}h.');
    }

    final busiest = months.reduce((a, b) => b.count > a.count ? b : a);
    out.add('Busiest month: ${fmtMonth(busiest.month)} with ${busiest.count} '
        'report${busiest.count == 1 ? '' : 's'}.');
    return out;
  }

  Widget _findingsCard(List<String> items) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: const [
            Icon(Icons.lightbulb_outline, size: 18, color: kOrange),
            SizedBox(width: 8),
            Text('KEY FINDINGS',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: kInk)),
          ]),
          const SizedBox(height: 8),
          for (final t in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                  padding: EdgeInsets.only(top: 5, right: 8),
                  child: Icon(Icons.circle, size: 6, color: kOrange),
                ),
                Expanded(
                    child: Text(t,
                        style: const TextStyle(fontSize: 12.5, color: kInk))),
              ]),
            ),
        ]),
      );

  // ---------- Charts ----------
  static const _noTitles = AxisTitles(sideTitles: SideTitles(showTitles: false));

  /// Y-axis step and top value (with headroom) for a count chart.
  ({int step, double maxY}) _yScale(int maxVal) {
    final step = math.max(1, (maxVal / 4).ceil());
    return (step: step, maxY: ((maxVal ~/ step) + 1) * step.toDouble());
  }

  AxisTitles _countAxis(int step) => AxisTitles(
        axisNameWidget: const Text('Reports',
            style: TextStyle(fontSize: 10, color: kMuted)),
        axisNameSize: 16,
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 26,
          interval: step.toDouble(),
          getTitlesWidget: (v, meta) => v == v.roundToDouble()
              ? Text('${v.toInt()}',
                  style: const TextStyle(fontSize: 10, color: kMuted))
              : const SizedBox(),
        ),
      );

  Widget _statusChart(List<Report> rs) {
    final byStatus = <String, int>{};
    for (final r in rs) {
      byStatus[r.status] = (byStatus[r.status] ?? 0) + 1;
    }
    final entries = byStatus.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = rs.length;

    return _Section(
      title: 'CASE STATUS DISTRIBUTION',
      subtitle: 'Share of reports by current status',
      child: Row(children: [
        Expanded(
          flex: 5,
          child: Stack(alignment: Alignment.center, children: [
            PieChart(PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 34,
              sections: [
                for (final e in entries)
                  PieChartSectionData(
                    value: e.value.toDouble(),
                    title: '${e.value}',
                    color: statusColor(e.key),
                    radius: 40,
                    titleStyle: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w900),
                  ),
              ],
            )),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$total',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900, color: kInk)),
              const Text('reports',
                  style: TextStyle(fontSize: 9, color: kMuted)),
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Icon(Icons.circle, size: 10, color: statusColor(e.key)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                              '${e.key}: ${e.value} '
                              '(${(e.value / total * 100).toStringAsFixed(0)}%)',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _areaChart(List<Report> rs) {
    final byArea = <String, int>{};
    for (final r in rs) {
      byArea[r.location] = (byArea[r.location] ?? 0) + 1;
    }
    final areas = (byArea.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(6)
        .toList();
    final scale = _yScale(areas.first.value);

    return _Section(
      title: 'REPORTS BY SUBDIVISION',
      subtitle: 'Top 6 subdivisions by number of reports',
      child: BarChart(BarChartData(
        maxY: scale.maxY,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
            drawVerticalLine: false, horizontalInterval: scale.step.toDouble()),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.transparent,
            tooltipPadding: EdgeInsets.zero,
            tooltipMargin: 2,
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                '${rod.toY.toInt()}',
                const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w900, color: kInk)),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: _noTitles,
          rightTitles: _noTitles,
          leftTitles: _countAxis(scale.step),
          bottomTitles: AxisTitles(
            axisNameWidget: const Text('Subdivision',
                style: TextStyle(fontSize: 10, color: kMuted)),
            axisNameSize: 16,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= areas.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SizedBox(
                    width: 56,
                    child: Text(areas[i].key,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 9, color: kMuted)),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < areas.length; i++)
            BarChartGroupData(
              x: i,
              showingTooltipIndicators: const [0],
              barRods: [
                BarChartRodData(
                  toY: areas[i].value.toDouble(),
                  width: 22,
                  gradient: const LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [kOrange, kAmber]),
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
        ],
      )),
    );
  }

  Widget _trendChart(List<_MonthCount> months) {
    final scale = _yScale(months.map((m) => m.count).reduce(math.max));
    final labelEvery = math.max(1, (months.length / 6).ceil());

    return _Section(
      title: 'INCIDENT REPORT TREND',
      subtitle: 'Number of reports received per month',
      child: LineChart(LineChartData(
        minX: 0,
        maxX: math.max(1, months.length - 1).toDouble(),
        minY: 0,
        maxY: scale.maxY,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
            drawVerticalLine: false, horizontalInterval: scale.step.toDouble()),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => kInk,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                    '${fmtMonth(months[s.x.toInt()].month)}: ${s.y.toInt()} '
                    'report${s.y.toInt() == 1 ? '' : 's'}',
                    const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
            ],
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: _noTitles,
          rightTitles: _noTitles,
          leftTitles: _countAxis(scale.step),
          bottomTitles: AxisTitles(
            axisNameWidget: const Text('Month reported',
                style: TextStyle(fontSize: 10, color: kMuted)),
            axisNameSize: 16,
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 24,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (v != i.toDouble() ||
                    i < 0 ||
                    i >= months.length ||
                    i % labelEvery != 0) {
                  return const SizedBox();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(fmtMonth(months[i].month),
                      style: const TextStyle(fontSize: 10, color: kMuted)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < months.length; i++)
                FlSpot(i.toDouble(), months[i].count.toDouble()),
            ],
            isCurved: true,
            preventCurveOverShooting: true,
            barWidth: 3,
            color: kOrange,
            dotData: const FlDotData(show: true),
            belowBarData:
                BarAreaData(show: true, color: const Color(0x33F97316)),
          ),
        ],
      )),
    );
  }

  Widget _charts(List<Report> rs, List<_MonthCount> months) {
    return LayoutBuilder(builder: (context, box) {
      final status = _statusChart(rs);
      final area = _areaChart(rs);
      final trend = _trendChart(months);
      if (box.maxWidth >= 1000) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: status),
          const SizedBox(width: 16),
          Expanded(child: area),
          const SizedBox(width: 16),
          Expanded(child: trend),
        ]);
      }
      return Column(children: [status, area, trend]);
    });
  }

  // ---------- Records (table + sort + pagination) ----------
  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(20)),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, color: color)),
      );

  Widget _recordsTable(List<Report> pageRows) {
    const cell = TextStyle(fontSize: 12.5, color: kInk);
    const muted = TextStyle(fontSize: 12.5, color: kMuted);
    return LayoutBuilder(builder: (context, box) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: box.maxWidth),
          child: DataTable(
            sortColumnIndex: _sortCol,
            sortAscending: _asc,
            columnSpacing: 24,
            headingRowHeight: 44,
            dataRowMinHeight: 46,
            dataRowMaxHeight: 52,
            headingRowColor:
                const WidgetStatePropertyAll(Color(0xFFFFF7ED)),
            headingTextStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w900, color: kInk),
            columns: [
              for (var i = 0; i < _columns.length; i++)
                DataColumn(
                  label: Text(_columns[i]),
                  onSort: (col, asc) => _update(() {
                    _sortCol = col;
                    _asc = asc;
                  }),
                ),
            ],
            rows: [
              for (final r in pageRows)
                DataRow(cells: [
                  DataCell(Text(r.id,
                      style: cell.copyWith(fontWeight: FontWeight.w800))),
                  DataCell(Text(r.animal, style: cell)),
                  DataCell(Text(r.location, style: cell)),
                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.circle, size: 9, color: priorityColor(r.priority)),
                    const SizedBox(width: 6),
                    Text(r.priority, style: cell),
                  ])),
                  DataCell(_chip(r.status, statusColor(r.status))),
                  DataCell(Text(fmtDate(r.reportedAt), style: cell)),
                  DataCell(Text(
                      r.resolvedAt == null ? '—' : fmtDate(r.resolvedAt!),
                      style: r.resolvedAt == null ? muted : cell)),
                  DataCell(Text(
                      r.responseHours == null
                          ? '—'
                          : '${r.responseHours!.toStringAsFixed(1)} hrs',
                      style: r.responseHours == null ? muted : cell)),
                ]),
            ],
          ),
        ),
      );
    });
  }

  Widget _pageButton(String label, bool selected, VoidCallback? onTap,
      {String? tooltip}) {
    final enabled = onTap != null;
    final btn = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? kOrange : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? kOrange : kBorder),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: selected
                    ? Colors.white
                    : (enabled ? kInk : const Color(0xFFD1D5DB)))),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip, child: btn);
  }

  Widget _pagination(int total, int pages, int page) {
    final from = total == 0 ? 0 : page * _pageSize + 1;
    final to = math.min(total, (page + 1) * _pageSize);
    final start = math.max(0, math.min(page - 2, pages - 5));
    final end = math.min(pages, start + 5);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 10,
        children: [
          Text('Showing $from–$to of $total records',
              style: const TextStyle(fontSize: 12, color: kMuted)),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('Rows per page ',
                style: TextStyle(fontSize: 12, color: kMuted)),
            _dropdown<int>(
              value: _pageSize,
              items: [
                for (final s in _pageSizes)
                  DropdownMenuItem(value: s, child: Text('$s')),
              ],
              onChanged: (v) => _update(() => _pageSize = v),
            ),
          ]),
          Row(mainAxisSize: MainAxisSize.min, children: [
            _pageButton('‹', false,
                page > 0 ? () => setState(() => _page = page - 1) : null,
                tooltip: 'Previous page'),
            for (var i = start; i < end; i++) ...[
              const SizedBox(width: 6),
              _pageButton('${i + 1}', i == page,
                  i == page ? null : () => setState(() => _page = i)),
            ],
            const SizedBox(width: 6),
            _pageButton('›', false,
                page < pages - 1 ? () => setState(() => _page = page + 1) : null,
                tooltip: 'Next page'),
          ]),
        ],
      ),
    );
  }

  Widget _records(List<Report> rs) {
    final sorted = _sorted(rs);
    final pages = math.max(1, (sorted.length / _pageSize).ceil());
    final page = _page.clamp(0, pages - 1);
    final pageRows =
        sorted.skip(page * _pageSize).take(_pageSize).toList();

    return Container(
      decoration: _cardDeco(),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 10,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.folder_open, size: 18, color: kOrange),
                const SizedBox(width: 8),
                Text('CASE RECORDS (${rs.length})',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: kInk)),
              ]),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('Sort by ',
                    style: TextStyle(fontSize: 12, color: kMuted)),
                _dropdown<int>(
                  value: _sortCol,
                  items: [
                    for (var i = 0; i < _columns.length; i++)
                      DropdownMenuItem(value: i, child: Text(_columns[i])),
                  ],
                  onChanged: (v) => _update(() => _sortCol = v),
                ),
                const SizedBox(width: 6),
                IconButton.outlined(
                  tooltip: _asc ? 'Ascending' : 'Descending',
                  onPressed: () => _update(() => _asc = !_asc),
                  icon: Icon(
                      _asc ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 18),
                ),
              ]),
            ],
          ),
        ),
        const Divider(height: 1),
        _recordsTable(pageRows),
        const Divider(height: 1),
        _pagination(sorted.length, pages, page),
      ]),
    );
  }

  Widget _emptyState() => Container(
        padding: const EdgeInsets.all(32),
        decoration: _cardDeco(),
        child: Column(children: [
          const Icon(Icons.search_off, size: 36, color: kMuted),
          const SizedBox(height: 8),
          const Text('No reports match your search or filters',
              style: TextStyle(fontWeight: FontWeight.w800, color: kInk)),
          const SizedBox(height: 8),
          TextButton(
              onPressed: _clearFilters, child: const Text('Clear filters')),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final rs = _filtered();
    final months = rs.isEmpty ? <_MonthCount>[] : _monthCounts(rs);

    return Scaffold(
      appBar: _appBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _banner(),
              const SizedBox(height: 14),
              _filterPanel(),
              const SizedBox(height: 14),
              if (rs.isEmpty)
                _emptyState()
              else ...[
                // KPI CARDS
                _kpiGrid(rs, months),
                const SizedBox(height: 16),
                _findingsCard(_findings(rs, months)),
                // GRAPHS
                _charts(rs, months),
                // RECORDS (table + sort + pagination)
                _records(rs),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Helpers ----------
class _MonthCount {
  final DateTime month;
  final int count;
  const _MonthCount(this.month, this.count);
}

/// Reports per calendar month, including months with zero reports between the
/// first and last report so the trend line has no gaps.
List<_MonthCount> _monthCounts(List<Report> rs) {
  final counts = <int, int>{};
  int key(DateTime d) => d.year * 12 + (d.month - 1);
  for (final r in rs) {
    counts[key(r.reportedAt)] = (counts[key(r.reportedAt)] ?? 0) + 1;
  }
  final lo = counts.keys.reduce(math.min);
  final hi = counts.keys.reduce(math.max);
  return [
    for (var k = lo; k <= hi; k++)
      _MonthCount(DateTime(k ~/ 12, k % 12 + 1), counts[k] ?? 0),
  ];
}

// ---------- Reusable widgets ----------
BoxDecoration _cardDeco() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 4))
      ],
    );

class _Kpi extends StatelessWidget {
  final String label, sub, value, footer;
  final IconData icon;
  final Color color;
  const _Kpi(this.label, this.sub, this.value, this.icon, this.color,
      this.footer);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: kInk)),
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: kMuted)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: color),
            ),
          ]),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 32, fontWeight: FontWeight.w900, color: kInk)),
          const Divider(height: 14),
          Row(children: [
            Icon(Icons.circle, size: 7, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(footer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title, subtitle;
  final Widget child;
  const _Section(
      {required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.circle, size: 10, color: kOrange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: kInk)),
            ),
          ]),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: kMuted)),
          const SizedBox(height: 14),
          SizedBox(height: 220, child: child),
        ],
      ),
    );
  }
}
