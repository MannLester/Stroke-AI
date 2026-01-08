import 'package:flutter/material.dart';
import '../models/health_data.dart';
import '../models/ppg_data.dart';
import '../services/database_service.dart';

class DataHistoryScreen extends StatefulWidget {
  const DataHistoryScreen({Key? key}) : super(key: key);

  @override
  State<DataHistoryScreen> createState() => _DataHistoryScreenState();
}

class _DataHistoryScreenState extends State<DataHistoryScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<HealthData> _healthDataList = [];
  Map<String, List<PPGData>> _ppgDataMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final healthData = await _databaseService.getAllHealthData();
      Map<String, List<PPGData>> ppgMap = {};
      
      for (final health in healthData) {
        final ppgData = await _databaseService.getPPGDataByHealthId(health.id);
        ppgMap[health.id] = ppgData;
      }

      setState(() {
        _healthDataList = healthData;
        _ppgDataMap = ppgMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteHealthData(HealthData healthData) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Data'),
          content: const Text('Are you sure you want to delete this measurement data?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        // Delete associated PPG data first
        final ppgDataList = _ppgDataMap[healthData.id] ?? [];
        for (final ppgData in ppgDataList) {
          await _databaseService.deletePPGData(ppgData.id);
        }
        
        // Delete health data
        await _databaseService.deleteHealthData(healthData.id);
        
        // Reload data
        _loadData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting data: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _exportData() async {
    try {
      final data = await _databaseService.getCompleteUserData();
      
      // For now, just show data count
      showDialog(
        context: context,
        builder: (BuildContext context) {
          final healthCount = (data['health_data'] as List).length;
          final ppgCount = (data['ppg_data'] as List).length;
          
          return AlertDialog(
            title: const Text('Export Data'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Health Records: $healthCount'),
                Text('PPG Records: $ppgCount'),
                const SizedBox(height: 16),
                const Text(
                  'Data export functionality will be implemented for research purposes.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getBMICategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  Color _getBMIColor(double bmi) {
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 25) return Colors.green;
    if (bmi < 30) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data History'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _exportData,
            icon: const Icon(Icons.download),
            tooltip: 'Export Data',
          ),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _healthDataList.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.data_usage, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No Data Available',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Start by taking your first PPG measurement.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _healthDataList.length,
                    itemBuilder: (context, index) {
                      final healthData = _healthDataList[index];
                      final ppgDataList = _ppgDataMap[healthData.id] ?? [];
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 3,
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            'Measurement ${index + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Date: ${_formatDate(healthData.timestamp)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text('Age: ${healthData.age}'),
                                  const SizedBox(width: 16),
                                  Text(
                                    'BMI: ${healthData.bmi.toStringAsFixed(1)}',
                                    style: TextStyle(color: _getBMIColor(healthData.bmi)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteHealthData(healthData),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Health Information
                                  const Text(
                                    'Health Information:',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildInfoCard('Age', '${healthData.age} years', Icons.cake),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildInfoCard(
                                          'BMI',
                                          '${healthData.bmi.toStringAsFixed(1)} kg/m²',
                                          Icons.monitor_weight,
                                          color: _getBMIColor(healthData.bmi),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _getBMIColor(healthData.bmi).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Category: ${_getBMICategory(healthData.bmi)}',
                                      style: TextStyle(
                                        color: _getBMIColor(healthData.bmi),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // PPG Data
                                  const Text(
                                    'PPG Measurements:',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 8),
                                  
                                  if (ppgDataList.isEmpty)
                                    const Card(
                                      child: Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Text(
                                          'No PPG measurements found for this record.',
                                          style: TextStyle(fontStyle: FontStyle.italic),
                                        ),
                                      ),
                                    )
                                  else
                                    ...ppgDataList.map((ppgData) => Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: _buildInfoCard(
                                                    'Heart Rate',
                                                    '${ppgData.heartRate} BPM',
                                                    Icons.favorite,
                                                    color: Colors.red,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: _buildInfoCard(
                                                    'Duration',
                                                    '${ppgData.duration.toStringAsFixed(1)}s',
                                                    Icons.timer,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(Icons.data_usage, size: 16, color: Colors.grey[600]),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Data Points: ${ppgData.rawValues.length}',
                                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                                ),
                                                const Spacer(),
                                                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _formatTime(ppgData.timestamp),
                                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (color ?? Colors.teal).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color ?? Colors.teal, size: 20),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.teal,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}