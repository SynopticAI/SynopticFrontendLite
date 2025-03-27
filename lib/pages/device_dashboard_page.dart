import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/latest_received_image.dart';
import '../device.dart';
import 'package:ai_device_manager/utils/app_theme.dart';
import 'package:ai_device_manager/l10n/app_localizations.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'package:intl/intl.dart';

enum TimeRange {
  lastHour,
  today,
  lastWeek
}

class DeviceDashboardPage extends StatefulWidget {
  final Device device;
  final String userId;

  const DeviceDashboardPage({
    Key? key,
    required this.device,
    required this.userId,
  }) : super(key: key);

  @override
  State<DeviceDashboardPage> createState() => _DeviceDashboardPageState();
}

class _DeviceDashboardPageState extends State<DeviceDashboardPage> {
  TimeRange _selectedTimeRange = TimeRange.lastHour;
  
  // Hardcoded bin parameters (ideally fetched from device config)
  final double resolution = 0.5; // Bin width
  final double maxValue = 5.0;   // Maximum expected output value

  // Stream for the latest inference result
  Stream<QuerySnapshot> get _latestInferenceStream => FirebaseFirestore.instance
      .collection('users')
      .doc(widget.userId)
      .collection('devices')
      .doc(widget.device.id)
      .collection('recent_outputs')
      .orderBy('timestamp', descending: true)
      .limit(1)
      .snapshots();

  // Stream for inference history based on time range
  Stream<List<DocumentSnapshot>> getInferenceHistoryStream() {
    final firestore = FirebaseFirestore.instance;
    final basePath = 'users/${widget.userId}/devices/${widget.device.id}';

    switch (_selectedTimeRange) {
      case TimeRange.lastHour:
        return firestore
            .collection('$basePath/recent_outputs')
            .orderBy('timestamp', descending: true)
            .limit(60) // Assuming up to 60 points in an hour
            .snapshots()
            .map((snapshot) => snapshot.docs);

      case TimeRange.today:
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
        return firestore
            .collection('$basePath/hourly_aggregations')
            .where('startTimestamp', isGreaterThanOrEqualTo: todayStart)
            .orderBy('startTimestamp', descending: true)
            .snapshots()
            .map((snapshot) => snapshot.docs);

      case TimeRange.lastWeek:
        final now = DateTime.now();
        final weekAgo = now.subtract(Duration(days: 7)).millisecondsSinceEpoch;
        return firestore
            .collection('$basePath/daily_aggregations')
            .where('startTimestamp', isGreaterThanOrEqualTo: weekAgo)
            .orderBy('startTimestamp', descending: true)
            .snapshots()
            .map((snapshot) => snapshot.docs);
    }
  }

  // Compute average output value from aggregated counts
  double computeAverage(Map<String, dynamic> counts, int totalCount) {
    if (totalCount == 0) return 0.0;
    double sum = 0;
    counts.forEach((binIndexStr, count) {
      int binIndex = int.parse(binIndexStr);
      double midpoint = (binIndex + 0.5) * resolution;
      sum += midpoint * (count as int);
    });
    return sum / totalCount;
  }

  // Build the latest inference card
  Widget _buildLatestInference() {
    return StreamBuilder<QuerySnapshot>(
      stream: _latestInferenceStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'No recent inference data',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          );
        }

        final doc = snapshot.data!.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        final outputValue = data['outputValue'] as double;
        final timestamp = data['timestamp'] as int;
        final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Latest Inference',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Text(
                  'Output Value: ${outputValue.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  'Timestamp: ${DateFormat('MMM d, yyyy h:mm a').format(dateTime)}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Build the inference history card with chart
  Widget _buildInferenceHistory() {
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: getInferenceHistoryStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Inference History',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      _buildTimeRangeSelector(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
          );
        }

        final entries = snapshot.data!;
        if (entries.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Inference History',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      _buildTimeRangeSelector(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'No inference history available',
                      style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Process data for the chart
        List<FlSpot> spots = [];
        List<DateTime> timestamps = [];

        if (_selectedTimeRange == TimeRange.lastHour) {
          // Use individual points from recent_outputs
          for (var doc in entries) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = data['timestamp'] as int;
            final outputValue = data['outputValue'] as double;
            spots.add(FlSpot(timestamp.toDouble(), outputValue));
            timestamps.add(DateTime.fromMillisecondsSinceEpoch(timestamp));
          }
        } else {
          // Use aggregated data (hourly or daily)
          for (var doc in entries) {
            final data = doc.data() as Map<String, dynamic>;
            final startTimestamp = data['startTimestamp'] as int;
            final counts = data['counts'] as Map<String, dynamic>;
            final totalCount = data['totalCount'] as int;
            final average = computeAverage(counts, totalCount);
            spots.add(FlSpot(startTimestamp.toDouble(), average));
            timestamps.add(DateTime.fromMillisecondsSinceEpoch(startTimestamp));
          }
        }

        // Sort by timestamp (ascending for chart)
        final sortedPairs = List.generate(spots.length, (i) => {'spot': spots[i], 'time': timestamps[i]});
        sortedPairs.sort((a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime));
        spots = sortedPairs.map((p) => p['spot'] as FlSpot).toList();
        timestamps = sortedPairs.map((p) => p['time'] as DateTime).toList();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Inference History',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    _buildTimeRangeSelector(),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: _buildHistoryChart(spots, timestamps),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Build the history chart
  Widget _buildHistoryChart(List<FlSpot> spots, List<DateTime> timestamps) {
    if (spots.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    double minY = spots.map((s) => s.y).reduce(min);
    double maxY = spots.map((s) => s.y).reduce(max);
    double yRange = maxY - minY;
    minY = minY - (yRange == 0 ? 1 : yRange * 0.1);
    maxY = maxY + (yRange == 0 ? 1 : yRange * 0.1);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          horizontalInterval: (maxY - minY) / 5,
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (spots.last.x - spots.first.x) / 5,
              getTitlesWidget: (value, meta) {
                final index = spots.indexWhere((s) => s.x == value);
                if (index == -1) return const SizedBox.shrink();
                final date = timestamps[index];
                String label;
                switch (_selectedTimeRange) {
                  case TimeRange.lastHour:
                    label = DateFormat('HH:mm').format(date);
                    break;
                  case TimeRange.today:
                    label = DateFormat('HH:00').format(date);
                    break;
                  case TimeRange.lastWeek:
                    label = DateFormat('MMM d').format(date);
                    break;
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(label, style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (maxY - minY) / 5,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(1),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withOpacity(0.15),
            ),
          ),
        ],
      ),
    );
  }

  // Time range selector
  Widget _buildTimeRangeSelector() {
    return DropdownButton<TimeRange>(
      value: _selectedTimeRange,
      underline: const SizedBox(),
      items: [
        DropdownMenuItem(
          value: TimeRange.lastHour,
          child: Text('Last Hour', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
        ),
        DropdownMenuItem(
          value: TimeRange.today,
          child: Text('Today', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
        ),
        DropdownMenuItem(
          value: TimeRange.lastWeek,
          child: Text('Last Week', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
        ),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedTimeRange = value);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_camera),
            tooltip: 'Test Inference',
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/test_camera',
                arguments: {'device': widget.device, 'userId': widget.userId},
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.device.name,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.device.taskDescription ?? 'No task description',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: widget.device.status == 'Operational'
                                ? Colors.green.withOpacity(0.2)
                                : Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            widget.device.status,
                            style: TextStyle(
                              color: widget.device.status == 'Operational'
                                  ? Colors.green[700]
                                  : Colors.orange[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'Latest Image',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: LatestReceivedImage(
                        userId: widget.userId,
                        deviceId: widget.device.id,
                        size: 300,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildLatestInference(),
            const SizedBox(height: 16),
            _buildInferenceHistory(),
          ],
        ),
      ),
    );
  }
}