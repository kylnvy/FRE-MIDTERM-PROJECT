// STRAY-SAFE Analytics (Flutter) - themed like the STRAY-SAFE web app.
// pubspec.yaml needs:
//   dependencies:
//     fl_chart: ^0.69.0
//   flutter:
//     assets:
//       - assets/reports.csv
// assets/reports.csv header: id,animal,location,priority,status,reported_at,resolved_at
//   animal   = Dog / Cat        location = subdivision name
//   priority = High / Medium / Low (assigned by the system)
//   status   = Pending, Endorsed, Escalated, Dispatched, Resolved,
//              Rejected, Deceased, Disputed or Archived
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
  final lines = raw.split('\n').skip(1).where((l) => l.trim().isNotEmpty);
  return lines.map((l) {
    final c = l.split(',').map((e) => e.trim()).toList();
    return Report(c[0], c[1], c[2], c[3], c[4], DateTime.parse(c[5]),
        c.length > 6 && c[6].isNotEmpty ? DateTime.parse(c[6]) : null);
  }).toList();
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

// ---------- Dashboard page ----------
/// The All / High / Medium / Low pills recompute the KPI cards, the 3 charts
/// and the records list from the filtered data.
class AnalyticsScreen extends StatefulWidget {
  final List<Report> reports;
  const AnalyticsScreen({super.key, required this.reports});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _priority = 'All';

  @override
  Widget build(BuildContext context) {
    const order = ['high', 'medium', 'low'];
    final found = widget.reports.map((r) => r.priority).toSet().toList()
      ..sort((a, b) {
        final ia = order.indexOf(a.toLowerCase());
        final ib = order.indexOf(b.toLowerCase());
        return (ia < 0 ? 9 : ia).compareTo(ib < 0 ? 9 : ib);
      });
    final shown = _priority == 'All'
        ? widget.reports
        : widget.reports.where((r) => r.priority == _priority).toList();

    Widget pill(String label, int count, Color? dot) {
      final sel = _priority == label;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _priority = label),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? kOrange : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sel ? kOrange : const Color(0xFFE5E7EB)),
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

    final filterBar = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        pill('All', widget.reports.length, null),
        for (final p in found)
          pill(p, widget.reports.where((r) => r.priority == p).length,
              priorityColor(p)),
      ]),
    );
    return _Dashboard(reports: shown, filterBar: filterBar);
  }
}

class _Dashboard extends StatelessWidget {
  final List<Report> reports;
  final Widget filterBar;
  const _Dashboard({required this.reports, required this.filterBar});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  Widget _intLabel(double v, TitleMeta meta) => v == v.roundToDouble()
      ? Text('${v.toInt()}', style: const TextStyle(fontSize: 10, color: kMuted))
      : const SizedBox();

  PreferredSizeWidget _appBar() => AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        title: Row(children: [
          const Icon(Icons.pets, color: kOrange),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text('SUBDIVISION ANALYTICS',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w900, color: kInk)),
            Text('STRAY-SAFE  •  SMART STRAY ANIMAL REPORTING',
                style: TextStyle(
                    fontSize: 9, letterSpacing: 0.6, color: kMuted)),
          ]),
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              Text("Here's what's happening",
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900, color: kInk)),
              SizedBox(height: 4),
              Text('Live summary of stray animal reports in your subdivision.',
                  style: TextStyle(fontSize: 12, color: kMuted)),
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

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return Scaffold(
        appBar: _appBar(),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            filterBar,
            const SizedBox(height: 24),
            const Center(child: Text('No reports for this filter')),
          ],
        ),
      );
    }

    // ---------- Chart data (computed from the records) ----------
    final byStatus = <String, int>{};
    final byArea = <String, int>{};
    final byMonth = <String, int>{};
    for (final r in reports) {
      byStatus[r.status] = (byStatus[r.status] ?? 0) + 1;
      byArea[r.location] = (byArea[r.location] ?? 0) + 1;
      final k =
          '${r.reportedAt.year}-${r.reportedAt.month.toString().padLeft(2, '0')}';
      byMonth[k] = (byMonth[k] ?? 0) + 1;
    }
    final statuses = byStatus.keys.toList();
    final areas = (byArea.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(6)
        .toList();
    final months = byMonth.keys.toList()..sort();

    // ---------- KPI values (computed) ----------
    final total = reports.length;
    final done = reports.where((r) => r.isResolved).length;
    final rate = done / total * 100;
    final active = reports.where((r) => !r.isClosed).length;
    final rejected = reports.where((r) => r.isRejected).length;
    final high =
        reports.where((r) => r.priority.toLowerCase() == 'high').length;
    final highOpen = reports
        .where((r) => r.priority.toLowerCase() == 'high' && !r.isClosed)
        .length;
    final hrs = reports
        .where((r) => r.isResolved)
        .map((r) => r.responseHours)
        .whereType<double>()
        .toList();
    final avgHrs =
        hrs.isEmpty ? null : hrs.reduce((a, b) => a + b) / hrs.length;
    final latest = byMonth[months.last]!;
    final sorted = [...reports]
      ..sort((a, b) => b.reportedAt.compareTo(a.reportedAt));

    const noTitles = AxisTitles(sideTitles: SideTitles(showTitles: false));

    return Scaffold(
      appBar: _appBar(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _banner(),
          const SizedBox(height: 14),
          filterBar,
          const SizedBox(height: 14),

          // ===================== KPI CARDS =====================
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 260,
                mainAxisExtent: 148,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12),
            children: [
              _Kpi('TOTAL REPORTS', 'All submitted reports', '$total',
                  Icons.description_outlined, kOrange, '$latest in latest month'),
              _Kpi('ACTIVE CASES', 'Awaiting action', '$active',
                  Icons.pending_actions, kBlue, 'not yet closed'),
              _Kpi('RESOLUTION RATE', 'Closed as resolved',
                  '${rate.toStringAsFixed(0)}%', Icons.verified_outlined,
                  kGreen, '$done of $total resolved'),
              _Kpi('HIGH PRIORITY', 'System-flagged urgent', '$high',
                  Icons.priority_high, kRed, '$highOpen still open'),
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
            ],
          ),
          const SizedBox(height: 16),

          // ===================== PIE: status =====================
          _Section(
            title: 'CASE STATUS DISTRIBUTION',
            subtitle: 'Where every report currently stands',
            child: Row(children: [
              Expanded(
                child: PieChart(PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 28,
                  sections: [
                    for (final s in statuses)
                      PieChartSectionData(
                        value: byStatus[s]!.toDouble(),
                        title: '${byStatus[s]}',
                        color: statusColor(s),
                        radius: 50,
                        titleStyle: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w900),
                      ),
                  ],
                )),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final s in statuses)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Icon(Icons.circle, size: 10, color: statusColor(s)),
                        const SizedBox(width: 6),
                        Text(s, style: const TextStyle(fontSize: 12)),
                      ]),
                    ),
                ],
              ),
            ]),
          ),

          // ===================== BAR: reports by subdivision =====================
          _Section(
            title: 'REPORTS BY SUBDIVISION',
            subtitle: 'Top 6 subdivisions by number of reports',
            child: BarChart(BarChartData(
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(drawVerticalLine: false),
              titlesData: FlTitlesData(
                topTitles: noTitles,
                rightTitles: noTitles,
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: _intLabel),
                ),
                bottomTitles: AxisTitles(
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
                              style: const TextStyle(
                                  fontSize: 9, color: kMuted)),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < areas.length; i++)
                  BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: areas[i].value.toDouble(),
                      width: 22,
                      gradient: const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [kOrange, kAmber]),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ]),
              ],
            )),
          ),

          // ===================== LINE: report trend =====================
          _Section(
            title: 'INCIDENT REPORT TREND',
            subtitle: 'Frequency of reports received per month',
            child: LineChart(LineChartData(
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(drawVerticalLine: false),
              titlesData: FlTitlesData(
                topTitles: noTitles,
                rightTitles: noTitles,
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: _intLabel),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (v != i.toDouble() || i < 0 || i >= months.length) {
                        return const SizedBox();
                      }
                      final m = int.parse(months[i].split('-')[1]);
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(_months[m - 1],
                            style: const TextStyle(
                                fontSize: 10, color: kMuted)),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < months.length; i++)
                      FlSpot(i.toDouble(), byMonth[months[i]]!.toDouble()),
                  ],
                  isCurved: true,
                  barWidth: 3,
                  color: kOrange,
                  dotData: const FlDotData(show: true),
                  belowBarData:
                      BarAreaData(show: true, color: const Color(0x33F97316)),
                ),
              ],
            )),
          ),

          // ===================== RECORDS =====================
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
            child: Row(children: [
              const Icon(Icons.folder_open, size: 18, color: kOrange),
              const SizedBox(width: 8),
              Text('CASE RECORDS ($total)',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: kInk)),
            ]),
          ),
          for (final r in sorted.take(50)) _RecordCard(r),
          if (sorted.length > 50)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Center(
                  child: Text('Showing 50 of ${sorted.length} records',
                      style: const TextStyle(color: kMuted, fontSize: 12))),
            ),
        ],
      ),
    );
  }
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
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                  color: color.withAlpha(30), shape: BoxShape.circle),
              child: Icon(Icons.arrow_upward, size: 10, color: color),
            ),
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
            Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: kInk)),
          ]),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: kMuted)),
          const SizedBox(height: 14),
          SizedBox(height: 190, child: child),
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  final Report r;
  const _RecordCard(this.r);

  static const _m = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  Widget build(BuildContext context) {
    final d = r.reportedAt;
    final sc = statusColor(r.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _cardDeco(),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(children: [
          Container(width: 5, color: priorityColor(r.priority)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text('ID #${r.id} — ${r.animal}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, color: kInk)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                        color: sc.withAlpha(30),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(r.status.toUpperCase(),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: sc)),
                  ),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: kMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                        '${r.location}  •  ${_m[d.month - 1]} ${d.day}, ${d.year}',
                        style: const TextStyle(fontSize: 12, color: kMuted)),
                  ),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.circle, size: 9, color: priorityColor(r.priority)),
                  const SizedBox(width: 6),
                  Text('${r.priority} priority',
                      style: const TextStyle(fontSize: 12, color: kInk)),
                  if (r.responseHours != null)
                    Text('   •   ${r.responseHours!.toStringAsFixed(1)} hrs to resolve',
                        style: const TextStyle(fontSize: 12, color: kMuted)),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
