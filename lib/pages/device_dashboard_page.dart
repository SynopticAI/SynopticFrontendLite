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
  
  // Class colors for consistent chart visualization
  final Map<String, Color> _classColors = {};
  final List<Color> _availableColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.indigo,
    Colors.pink,
    Colors.amber,
    Colors.cyan,
  ];
  
  // Class filtering state
  Set<String> _activeClasses = <String>{};

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
            .limit(60) // Last 60 data points
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

  Color _getClassColor(String className) {
    if (!_classColors.containsKey(className)) {
      final colorIndex = _classColors.length % _availableColors.length;
      _classColors[className] = _availableColors[colorIndex];
    }
    return _classColors[className]!;
  }
  
  // Handle class selection for filtering
  void _toggleClassSelection(String className, Set<String> allClasses) {
    setState(() {
      if (_activeClasses.isEmpty) {
        // If no filter active, show all classes initially
        _activeClasses.addAll(allClasses);
      }
      
      if (_activeClasses.contains(className) && _activeClasses.length == 1) {
        // If this is the only active class, show all classes
        _activeClasses.clear();
        _activeClasses.addAll(allClasses);
      } else {
        // Show only the selected class
        _activeClasses.clear();
        _activeClasses.add(className);
      }
    });
  }
  
  // Check if a class should be displayed actively
  bool _isClassActive(String className, Set<String> allClasses) {
    if (_activeClasses.isEmpty) {
      return true; // Show all classes when no filter is active
    }
    return _activeClasses.contains(className);
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
        final outputValue = (data['outputValue'] as num?)?.toDouble() ?? 0.0;
        final timestamp = (data['timestamp'] as num?)?.toInt() ?? 0;
        final inferenceMode = data['inferenceMode'] as String? ?? 'Unknown';
        final classMetrics = data['classMetrics'] as Map<String, dynamic>? ?? {};
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
                
                // Total detections
                Row(
                  children: [
                    Icon(Icons.visibility, color: AppTheme.primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Total Detections: ${outputValue.toInt()}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Inference mode
                Row(
                  children: [
                    Icon(Icons.settings, color: Colors.grey[600], size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Mode: $inferenceMode',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Timestamp
                Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.grey[600], size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Time: ${DateFormat('MMM d, yyyy h:mm a').format(dateTime)}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                
                // Class breakdown if available
                if (classMetrics.containsKey('classCounts')) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Class Breakdown:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                                      ...(() {
                    final classCounts = classMetrics['classCounts'] as Map<String, dynamic>? ?? {};
                    return classCounts.entries.map((entry) {
                      final className = entry.key;
                      final count = (entry.value as num?)?.toInt() ?? 0;
                      final color = _getClassColor(className);
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('$className: $count'),
                          ],
                        ),
                      );
                    }).toList();
                  })(),
                ],
                
                // Confidence if available
                if (classMetrics.containsKey('averageConfidence')) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.stars, color: Colors.amber, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Avg. Confidence: ${(((classMetrics['averageConfidence'] as num?)?.toDouble() ?? 0.0) * 100).toStringAsFixed(1)}%',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // Build the detection history chart
  Widget _buildClassDetectionHistory() {
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
                        'Detections',
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
                        'Detections',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      _buildTimeRangeSelector(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child:                     Text(
                      'No detection data available',
                      style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Process data for the chart
        Map<String, List<FlSpot>> classData = {};
        List<DateTime> timestamps = [];
        Set<String> allClasses = {};

        // Sort entries by timestamp (ascending for chart)
        final sortedEntries = entries.toList();
        sortedEntries.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = ((aData['timestamp'] ?? aData['startTimestamp']) as num?)?.toInt() ?? 0;
          final bTime = ((bData['timestamp'] ?? bData['startTimestamp']) as num?)?.toInt() ?? 0;
          return aTime.compareTo(bTime);
        });

        for (var doc in sortedEntries) {
          final data = doc.data() as Map<String, dynamic>;
          final timestamp = ((data['timestamp'] ?? data['startTimestamp']) as num?)?.toInt() ?? 0;
          timestamps.add(DateTime.fromMillisecondsSinceEpoch(timestamp));

          Map<String, dynamic> classCounts = {};
          
          if (_selectedTimeRange == TimeRange.lastHour) {
            // Use classMetrics.classCounts from recent_outputs (individual inference results)
            final classMetrics = data['classMetrics'] as Map<String, dynamic>? ?? {};
            classCounts = classMetrics['classCounts'] as Map<String, dynamic>? ?? {};
          } else {
            // Calculate average from aggregations (classTotals / totalCount)
            final classTotals = data['classTotals'] as Map<String, dynamic>? ?? {};
            final totalCount = (data['totalCount'] as num?)?.toInt() ?? 1; // Prevent division by zero
            
            // Convert totals to averages
            classCounts = {};
            for (final entry in classTotals.entries) {
              final totalDetections = (entry.value as num?)?.toInt() ?? 0;
              final averageDetections = totalCount > 0 ? (totalDetections / totalCount).round() : 0;
              classCounts[entry.key] = averageDetections;
            }
          }

          // Add classes to our tracking
          allClasses.addAll(classCounts.keys);

          // Create data points for each class
          for (final className in allClasses) {
            if (!classData.containsKey(className)) {
              classData[className] = [];
            }
            
            final count = (classCounts[className] as num?)?.toInt() ?? 0;
            classData[className]!.add(FlSpot(timestamp.toDouble(), count.toDouble()));
          }
        }

        // Fill in missing data points for consistent lines
        for (final className in allClasses) {
          final spots = classData[className]!;
          if (spots.length < timestamps.length) {
            for (int i = 0; i < timestamps.length; i++) {
              final timestamp = timestamps[i].millisecondsSinceEpoch.toDouble();
              final hasSpot = spots.any((spot) => spot.x == timestamp);
              if (!hasSpot) {
                spots.add(FlSpot(timestamp, 0));
              }
            }
            // Sort spots by timestamp
            spots.sort((a, b) => a.x.compareTo(b.x));
          }
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Detections',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    _buildTimeRangeSelector(),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Legend
                if (allClasses.isNotEmpty) ...[
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: allClasses.map((className) {
                      final color = _getClassColor(className);
                      final isActive = _isClassActive(className, allClasses);
                      
                      return GestureDetector(
                        onTap: () => _toggleClassSelection(className, allClasses),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: isActive ? color : Colors.grey[400],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontSize: 12, 
                                color: isActive ? Colors.grey[700] : Colors.grey[400],
                              ),
                              child: Text(className),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Chart
                SizedBox(
                  height: 250,
                  child: _buildClassDetectionChart(classData, timestamps, allClasses),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Build the class detection chart
  Widget _buildClassDetectionChart(Map<String, List<FlSpot>> classData, List<DateTime> timestamps, Set<String> allClasses) {
    if (classData.isEmpty || timestamps.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    // Find min/max values for scaling (only for active classes)
    double maxY = 0;
    for (final entry in classData.entries) {
      if (_isClassActive(entry.key, allClasses)) {
        for (final spot in entry.value) {
          if (spot.y > maxY) maxY = spot.y;
        }
      }
    }
    
    if (maxY == 0) maxY = 1; // Prevent division by zero

    // Calculate safe intervals to prevent zero values
    final timeSpan = timestamps.isNotEmpty && timestamps.length > 1 
        ? (timestamps.last.millisecondsSinceEpoch - timestamps.first.millisecondsSinceEpoch).toDouble()
        : 3600000.0; // Default to 1 hour if no time span
    final verticalInterval = max(timeSpan / 5, 60000.0); // Minimum 1 minute intervals
    final horizontalInterval = max(maxY / 5, 1.0);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          horizontalInterval: horizontalInterval,
          verticalInterval: verticalInterval,
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: max(timeSpan / 4, 60000.0), // Minimum 1 minute intervals
              getTitlesWidget: (value, meta) {
                final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
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
              interval: horizontalInterval,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        minY: 0,
        maxY: maxY + (maxY * 0.1), // Add 10% padding
        lineBarsData: classData.entries.where((entry) {
          // Only show lines for active classes
          return _isClassActive(entry.key, allClasses);
        }).map((entry) {
          final className = entry.key;
          final spots = entry.value;
          final color = _getClassColor(className);
          
          return LineChartBarData(
            spots: spots,
            isCurved: false, // Use linear interpolation to prevent overshooting
            color: color,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: color,
                  strokeWidth: 1,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: color.withOpacity(0.1),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Time range selector
  Widget _buildTimeRangeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButton<TimeRange>(
        value: _selectedTimeRange,
        underline: const SizedBox(),
        isDense: true,
        items: [
          DropdownMenuItem(
            value: TimeRange.lastHour,
            child: Text('1H', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          ),
          DropdownMenuItem(
            value: TimeRange.today,
            child: Text('1D', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          ),
          DropdownMenuItem(
            value: TimeRange.lastWeek,
            child: Text('7D', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          ),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() => _selectedTimeRange = value);
          }
        },
      ),
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
            // Device info and latest image
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
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: widget.device.status == 'Operational'
                                          ? Colors.green.withOpacity(0.2)
                                          : Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      widget.device.status,
                                      style: TextStyle(
                                        color: widget.device.status == 'Operational'
                                            ? Colors.green[700]
                                            : Colors.orange[700],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      widget.device.inferenceMode,
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
            
            // Latest inference results
            _buildLatestInference(),
            const SizedBox(height: 16),
            
            // Detection history chart
            _buildClassDetectionHistory(),
          ],
        ),
      ),
    );
  }
}