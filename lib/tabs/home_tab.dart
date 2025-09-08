import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/dashboard/providers/admin_provider.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  @override
  void initState() {
    super.initState();
    // Kick off loading once the widget is mounted
    Future.microtask(() {
      final auth = context.read<AuthProvider>();
      final token = auth.token;
      if (token != null) {
        context.read<AdminProvider>().loadDashboard(token);
      }
    });
  }

  Future<void> _onRefresh() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token != null) {
      await context.read<AdminProvider>().loadDashboard(token);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          // Summary cards (counts)
          _sectionTitle("Dashboard"),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            children: [
              _summaryCard("Devices", admin.summary?['device_count'] ?? 0, Icons.devices_other, Colors.teal),
              _summaryCard("Stations", admin.summary?['station_count'] ?? 0, Icons.location_city, Colors.green),
              _summaryCard("Gates", admin.summary?['gate_count'] ?? 0, Icons.meeting_room, Colors.orange),
              _summaryCard("Users", admin.summary?['user_count'] ?? 0, Icons.people, Colors.blue),
            ],
          ),

          _sectionTitle("Tasks"),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _summaryCard("All", admin.summary?['tasks_count'] ?? 0, Icons.task_alt, Colors.blue),
              _summaryCard("Pending", admin.summary?['tasks_pending_count'] ?? 0, Icons.task_alt, Colors.orange),
              _summaryCard("In Progress", admin.summary?['tasks_inprogress_count'] ?? 0, Icons.task_alt, Colors.blueAccent),
              _summaryCard("Completed", admin.summary?['tasks_completed_count'] ?? 0, Icons.task_alt, Colors.green),
            ],
          ),

          const SizedBox(height: 10),
          _sectionTitle("Daily Transactions"),
          _chartCard(
            height: 260,
            child: admin.dailyTransactions == null
                ? const _LoadingOrEmpty()
                : _dailyAmountBarChart(admin.dailyTransactions!),
          ),

          const SizedBox(height: 10),
          _sectionTitle("Station Wise"),
          _chartCard(
            height: 320,
            child: admin.stationTotals == null
                ? const _LoadingOrEmpty()
                : _stationTotalsBarChart(admin.stationTotals!),
          ),

          const SizedBox(height: 10),

          // Top devices list
          _sectionTitle("Devices"),
          _deviceList(admin.deviceTransactions),

          const SizedBox(height: 10),

          // Users list
          _sectionTitle("Users"),
          _usersList(admin.users),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _summaryCard(String title, dynamic value, IconData icon, Color color) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min, // prevent overflow
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(height: 2),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chartCard({required double height, required Widget child}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(height: height, child: Padding(padding: const EdgeInsets.all(12), child: child)),
    );
  }

  // ---------- Charts ----------
  Widget _dailyAmountBarChart(Map<String, dynamic> daily) {
    final entries = daily.entries
        .where((e) => (e.value['amount'] as num?) != null && (e.value['amount'] as num) > 0)
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (entries.isEmpty) {
      return const Center(child: Text("No data available"));
    }

    // ---- Layout knobs ----
    const double barWidth = 10;      // width of each rod
    const double barsSpace = 4;      // space between rods inside a group
    const double groupsSpace = 12;   // space between groups
    const int targetVisibleGroups = 10; // show ~10 groups at a time

    // Each group has 2 rods (tickets + passengers)
    final double groupVisualWidth = (barWidth * 2) + barsSpace + groupsSpace;
    final int totalGroups = entries.length;

    // The full chart needs width for all groups to enable scrolling
    final double fullChartWidth = max(
      targetVisibleGroups * groupVisualWidth,             // so at least 10 are visible
      totalGroups * groupVisualWidth,                     // but wide enough for all
    );

    // Build bar groups
    final barGroups = <BarChartGroupData>[];
    for (var i = 0; i < entries.length; i++) {
      final passengers = (entries[i].value['passengers'] as num).toDouble();
      final tickets = (entries[i].value['tickets'] as num).toDouble();

      barGroups.add(
        BarChartGroupData(
          x: i,
          barsSpace: barsSpace,
          groupVertically: false,
          barRods: [
            BarChartRodData(
              toY: tickets,
              width: barWidth,
              borderRadius: BorderRadius.circular(4),
              color: Colors.blue,
            ),
            BarChartRodData(
              toY: passengers,
              width: barWidth,
              borderRadius: BorderRadius.circular(4),
              color: Colors.orange,
            ),
          ],
        ),
      );
    }

    // Wrap in a horizontal scroll view so only ~10 groups show at once
    return SizedBox(
      height: 260, // adjust as needed
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: fullChartWidth,
          child: BarChart(
            BarChartData(
              groupsSpace: groupsSpace,
              gridData: FlGridData(show: true),
              borderData: FlBorderData(
                show: true,
                border: const Border(
                  left: BorderSide(color: Colors.black, width: 1),
                  bottom: BorderSide(color: Colors.black, width: 1),
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= entries.length) return const SizedBox.shrink();
                      final date = entries[idx].key; // "YYYY-MM-DD"
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(date.split('-').last), // show day
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const Text("0");
                      if (value >= 1000) return Text("${(value / 1000).toStringAsFixed(0)}k");
                      return Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          fontSize: 10,   // smaller than default (usually ~14–16)
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: barGroups,
            ),
          ),
        ),
      ),
    );
  }

  /// Station totals bar chart from `station_totals`: stationCode -> { amount, passengers, tickets }
  Widget _stationTotalsBarChart(Map<String, dynamic> stationTotals) {
    // Prepare & sort entries by station name
    final entries = stationTotals.entries
        .where((e) {
      final v = e.value;
      num t = (v['device_transactions_count'] as num?) ?? 0;
      num pc = (v['device_transactions_passengers_count'] as num?) ?? 0;
      return (t + pc) > 0;
    })
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (entries.isEmpty) {
      return const Center(child: Text("No data available"));
    }

    // -------- Layout knobs --------
    const double barWidth = 10;        // width of each rod
    const double barsSpace = 4;        // space between rods inside a group
    const double groupsSpace = 6;     // space between groups
    const int targetVisibleGroups = 10;
    const double axisFontSize = 10;    // compact labels
    const double chartHeight = 260;    // chart area height

    // We have 3 bars per group (tickets, passengers, passengerCount)
    const int rodsPerGroup = 2;

    // width per group ≈ bars + internal spaces + inter-group space
    final double groupVisualWidth =
        (barWidth * rodsPerGroup) + (barsSpace * (rodsPerGroup - 1)) + groupsSpace;

    final int totalGroups = entries.length;

    // Make the inner canvas wide enough so ~10 groups are visible, but also wide enough for all groups
    final double fullChartWidth = max(
      targetVisibleGroups * groupVisualWidth,
      totalGroups * groupVisualWidth,
    );

    // -------- Build bar groups --------
    final barGroups = <BarChartGroupData>[];
    for (var i = 0; i < entries.length; i++) {
      final v = entries[i].value;
      final tickets = (v['device_transactions_count'] as num?)?.toDouble() ?? 0.0;
      final passengerCount =
          (v['device_transactions_passengers_count'] as num?)?.toDouble() ?? 0.0;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barsSpace: barsSpace,
          groupVertically: false,
          barRods: [
            BarChartRodData(
              toY: tickets,
              width: barWidth,
              borderRadius: BorderRadius.circular(4),
              color: Colors.blue,
            ),
            BarChartRodData(
              toY: passengerCount,
              width: barWidth,
              borderRadius: BorderRadius.circular(4),
              color: Colors.orange,
            ),
          ],
        ),
      );
    }

    // -------- Tooltip formatting --------
    BarTooltipItem _tooltipFor(int groupIndex, int rodIndex, double y) {
      final station = entries[groupIndex].key;
      final label = switch (rodIndex) {
        0 => 'Tickets',
        1 => 'Passenger Cnt',
        _ => 'Value',
      };
      return BarTooltipItem(
        '$station\n$label: ${y.toStringAsFixed(0)}',
        const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white),
      );
    }

    // -------- Chart + legend --------
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            children: const [
              _LegendItem(color: Colors.blue, label: 'Tickets'),
              _LegendItem(color: Colors.orange, label: 'Passenger Count'),
            ],
          ),
        ),

        // Scrollable chart
        SizedBox(
          height: chartHeight,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: fullChartWidth,
              child: BarChart(
                BarChartData(
                  groupsSpace: groupsSpace,
                  minY: 0, // keep baseline at 0
                  barGroups: barGroups,
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(
                    show: true,
                    border: const Border(
                      left: BorderSide(color: Colors.black, width: 1),
                      bottom: BorderSide(color: Colors.black, width: 1),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),

                    // X axis: station names (shortened)
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= entries.length) {
                            return const SizedBox.shrink();
                          }
                          final station = entries[idx].key;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: SizedBox(
                              width: groupVisualWidth, // room per group label
                              child: Text(
                                _shorten(station, 5),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: axisFontSize),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Y axis: compact with k-suffix
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) {
                            return const Text("0", style: TextStyle(fontSize: axisFontSize));
                          }
                          if (value >= 1000) {
                            return Text(
                              "${(value / 1000).toStringAsFixed(0)}k",
                              style: const TextStyle(fontSize: axisFontSize),
                            );
                          }
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: axisFontSize),
                          );
                        },
                      ),
                    ),
                  ),

                  // Tooltips
                  barTouchData: BarTouchData(
                    enabled: true,
                    handleBuiltInTouches: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipPadding: const EdgeInsets.all(8),
                      tooltipRoundedRadius: 6,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return _tooltipFor(groupIndex, rodIndex, rod.toY);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }


  /// Shorten long labels with ellipsis.
  String _shorten(String value, int maxChars) {
    if (value.length <= maxChars) return value;
    return value.substring(0, maxChars - 1) + '…';
  }

  // ---------- Lists ----------
  Widget _deviceList(List<dynamic> devices) {
    if (devices.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No device data found'),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: SizedBox(
        height: 300, // 👈 adjust so ~5 items fit
        child: ListView.separated(
          padding: const EdgeInsets.all(8),
          itemCount: devices.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final d = devices[i] as Map<String, dynamic>;
            final serial = (d['serial_number'] ?? '').toString();
            final amount = double.tryParse((d['total_device_transactions_amount'] ?? '0').toString()) ?? 0.0;
            final count = (d['device_transactions_count'] as num?)?.toInt() ?? 0;
            final passengerCount = int.tryParse((d['total_device_transactions_passengers_count'] ?? '0').toString()) ?? 0;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.teal.withOpacity(0.1),
                child: const Icon(Icons.devices_other, color: Colors.teal),
              ),
              title: Text(
                serial,
                style: const TextStyle(fontSize: 12),
              ),
              subtitle: Text(
                'Tickets: $count \nPassenger Count: $passengerCount',
                style: const TextStyle(fontSize: 10, height: 1.2),
              ),
              trailing: Text(
                '₹${amount.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _usersList(List<dynamic> users) {
    if (users.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No users found'),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: SizedBox(
        height: 360, // 👈 adjust so ~6 rows fit
        child: ListView.separated(
          padding: const EdgeInsets.all(2),
          itemCount: users.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final u = users[i] as Map<String, dynamic>;
            final name = (u['name'] ?? '').toString();
            final role = (u['role'] ?? '').toString();
            final profile = u['profile_image'] as String?;
            final hasProfile = profile != null && profile.isNotEmpty;

            int _asInt(dynamic v) {
              if (v == null) return 0;
              if (v is num) return v.toInt();
              if (v is String) return int.tryParse(v) ?? 0;
              return 0;
            }

            double asDouble(dynamic v) {
              if (v == null) return 0.0;
              if (v is num) return v.toDouble();
              if (v is String) return double.tryParse(v) ?? 0.0;
              return 0.0;
            }

            final int deviceCount      = _asInt(u['device_count']);
            final int ticketSold       = _asInt(u['ticket_sold']);
            final double ticketSoldPct = asDouble(u['ticket_sold_percentage']);

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: hasProfile
                    ? NetworkImage(profile)
                    : const AssetImage('assets/images/profile.jpg') as ImageProvider,
              ),
              title: Text(
                name,
                style: const TextStyle(fontSize: 12),
              ),
              subtitle: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(role, style: const TextStyle(fontSize: 10)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text('Assign Devices: $deviceCount', style: const TextStyle(fontSize: 10)),
                      const SizedBox(width: 8),
                      Text('Tickets: $ticketSold', style: const TextStyle(fontSize: 10)),
                      const SizedBox(width: 8),
                      Text('Sold: ${ticketSoldPct.toStringAsFixed(1)}%',
                          style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              isThreeLine: true,
              onTap: () {
                // TODO: Navigate to user details, if needed
              },
            );
          },
        ),
      ),
    );
  }
}

class _LoadingOrEmpty extends StatelessWidget {
  const _LoadingOrEmpty();

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    if (admin.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (admin.error != null) {
      return Center(child: Text('Error: ${admin.error}'));
    }
    return const Center(child: Text('No data'));
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}