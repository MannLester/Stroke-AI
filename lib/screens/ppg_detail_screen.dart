import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/ppg_data.dart';

class PPGDetailScreen extends StatefulWidget {
  final PPGData ppgData;

  const PPGDetailScreen({Key? key, required this.ppgData}) : super(key: key);

  @override
  State<PPGDetailScreen> createState() => _PPGDetailScreenState();
}

class _PPGDetailScreenState extends State<PPGDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PPG Data Details'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.show_chart), text: 'Waveform'),
            Tab(icon: Icon(Icons.table_chart), text: 'Data Table'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Summary Card
          _buildSummaryCard(),
          
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildWaveformTab(),
                _buildDataTableTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.favorite,
                  label: 'Avg BPM',
                  value: '${widget.ppgData.heartRate}',
                  color: Colors.red,
                ),
                _buildStatItem(
                  icon: Icons.trending_down,
                  label: 'Min BPM',
                  value: '${widget.ppgData.minBpm ?? "-"}',
                  color: Colors.blue,
                ),
                _buildStatItem(
                  icon: Icons.trending_up,
                  label: 'Max BPM',
                  value: '${widget.ppgData.maxBpm ?? "-"}',
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.timer,
                  label: 'Duration',
                  value: '${widget.ppgData.duration.toStringAsFixed(1)}s',
                  color: Colors.teal,
                ),
                _buildStatItem(
                  icon: Icons.timeline,
                  label: 'HRV (SDNN)',
                  value: widget.ppgData.hrv != null 
                      ? '${widget.ppgData.hrv!.toStringAsFixed(1)}ms' 
                      : '-',
                  color: Colors.purple,
                ),
                _buildStatItem(
                  icon: Icons.data_usage,
                  label: 'Data Points',
                  value: '${widget.ppgData.rawValues.length}',
                  color: Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildWaveformTab() {
    if (widget.ppgData.rawValues.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No waveform data available',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PPG Waveform Chart
          const Text(
            'PPG Signal Waveform',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Raw sensor values over time',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: _buildPPGWaveformChart(),
          ),
          
          const SizedBox(height: 32),
          
          // BPM Over Time Chart
          if (widget.ppgData.bpmReadings.isNotEmpty) ...[
            const Text(
              'Heart Rate Over Time',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'BPM readings during measurement',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _buildBPMChart(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPPGWaveformChart() {
    final data = widget.ppgData.rawValues;
    
    // Normalize data for better visualization
    double minVal = data.reduce((a, b) => a < b ? a : b);
    double maxVal = data.reduce((a, b) => a > b ? a : b);
    double range = maxVal - minVal;
    if (range == 0) range = 1;
    
    // Sample data if too many points (for performance)
    List<FlSpot> spots = [];
    int step = data.length > 500 ? (data.length / 500).ceil() : 1;
    
    for (int i = 0; i < data.length; i += step) {
      double normalizedValue = (data[i] - minVal) / range * 100;
      spots.add(FlSpot(i.toDouble(), normalizedValue));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 25,
          verticalInterval: data.length / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey[300]!,
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Colors.grey[300]!,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: data.length / 5,
              getTitlesWidget: (value, meta) {
                if (widget.ppgData.timestamps.isNotEmpty && 
                    value.toInt() < widget.ppgData.timestamps.length) {
                  int ms = widget.ppgData.timestamps[value.toInt()];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${(ms / 1000).toStringAsFixed(1)}s',
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey[300]!),
        ),
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: Colors.red,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.red.withOpacity(0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                int index = spot.x.toInt();
                double actualValue = index < data.length ? data[index] : 0;
                return LineTooltipItem(
                  'Value: ${actualValue.toStringAsFixed(2)}',
                  const TextStyle(color: Colors.white),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBPMChart() {
    final bpmData = widget.ppgData.bpmReadings;
    
    List<FlSpot> spots = [];
    for (int i = 0; i < bpmData.length; i++) {
      spots.add(FlSpot(i.toDouble(), bpmData[i].toDouble()));
    }

    double minBpm = bpmData.isNotEmpty 
        ? bpmData.reduce((a, b) => a < b ? a : b).toDouble() - 10 
        : 40;
    double maxBpm = bpmData.isNotEmpty 
        ? bpmData.reduce((a, b) => a > b ? a : b).toDouble() + 10 
        : 200;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey[300]!,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: bpmData.length > 10 ? bpmData.length / 5 : 1,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${value.toInt()}',
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 20,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey[300]!),
        ),
        minX: 0,
        maxX: (bpmData.length - 1).toDouble(),
        minY: minBpm,
        maxY: maxBpm,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: Colors.teal,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: bpmData.length < 50,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: Colors.teal,
                  strokeWidth: 1,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.teal.withOpacity(0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '${spot.y.toInt()} BPM',
                  const TextStyle(color: Colors.white),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDataTableTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // BPM Readings Table
          if (widget.ppgData.bpmReadings.isNotEmpty) ...[
            const Text(
              'BPM Readings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('BPM', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: List.generate(
                    widget.ppgData.bpmReadings.length,
                    (index) {
                      int bpm = widget.ppgData.bpmReadings[index];
                      String status = _getBpmStatus(bpm);
                      Color statusColor = _getBpmStatusColor(bpm);
                      
                      return DataRow(
                        cells: [
                          DataCell(Text('${index + 1}')),
                          DataCell(Text('$bpm')),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Raw PPG Values Table
          if (widget.ppgData.rawValues.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Raw PPG Signal Values',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${widget.ppgData.rawValues.length} samples',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Time (ms)', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Value', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: List.generate(
                    // Show max 100 rows for performance
                    widget.ppgData.rawValues.length > 100 
                        ? 100 
                        : widget.ppgData.rawValues.length,
                    (index) {
                      int actualIndex = widget.ppgData.rawValues.length > 100
                          ? (index * widget.ppgData.rawValues.length / 100).floor()
                          : index;
                      
                      double value = widget.ppgData.rawValues[actualIndex];
                      int timestamp = widget.ppgData.timestamps.isNotEmpty &&
                              actualIndex < widget.ppgData.timestamps.length
                          ? widget.ppgData.timestamps[actualIndex]
                          : actualIndex * 33; // Approximate 30fps
                      
                      return DataRow(
                        cells: [
                          DataCell(Text('${actualIndex + 1}')),
                          DataCell(Text('$timestamp')),
                          DataCell(Text(value.toStringAsFixed(4))),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            if (widget.ppgData.rawValues.length > 100)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Showing 100 of ${widget.ppgData.rawValues.length} samples (sampled for display)',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
          
          // Statistics Summary
          const SizedBox(height: 24),
          const Text(
            'Statistics Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildStatRow('Measurement ID', widget.ppgData.id),
                  _buildStatRow('Date', _formatDate(widget.ppgData.timestamp)),
                  _buildStatRow('Time', _formatTime(widget.ppgData.timestamp)),
                  _buildStatRow('Duration', '${widget.ppgData.duration.toStringAsFixed(2)} seconds'),
                  _buildStatRow('Average Heart Rate', '${widget.ppgData.heartRate} BPM'),
                  if (widget.ppgData.minBpm != null)
                    _buildStatRow('Minimum Heart Rate', '${widget.ppgData.minBpm} BPM'),
                  if (widget.ppgData.maxBpm != null)
                    _buildStatRow('Maximum Heart Rate', '${widget.ppgData.maxBpm} BPM'),
                  if (widget.ppgData.hrv != null)
                    _buildStatRow('HRV (SDNN)', '${widget.ppgData.hrv!.toStringAsFixed(2)} ms'),
                  _buildStatRow('Total BPM Readings', '${widget.ppgData.bpmReadings.length}'),
                  _buildStatRow('Raw Data Points', '${widget.ppgData.rawValues.length}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  String _getBpmStatus(int bpm) {
    if (bpm < 60) return 'Low';
    if (bpm <= 100) return 'Normal';
    return 'High';
  }

  Color _getBpmStatusColor(int bpm) {
    if (bpm < 60) return Colors.blue;
    if (bpm <= 100) return Colors.green;
    return Colors.orange;
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }
}
