import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const ProviderScope(child: AirQualityApp()));
}

class AirQualityApp extends StatelessWidget {
  const AirQualityApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Air Quality Monitor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}

// Models
class AirQualityData {
  final double co2;
  final double ammonia;
  final double no2;
  final double benzene;
  final double temperature;
  final double humidity;
  final String airQuality;
  final String fan;
  final String fanMode;
  final String buzzer;
  final String buzzerMode;
  final Map<String, double> thresholds;
  final DateTime timestamp;

  AirQualityData({
    required this.co2,
    required this.ammonia,
    required this.no2,
    required this.benzene,
    required this.temperature,
    required this.humidity,
    required this.airQuality,
    required this.fan,
    required this.fanMode,
    required this.buzzer,
    required this.buzzerMode,
    required this.thresholds,
    required this.timestamp,
  });


  factory AirQualityData.fromJson(Map<String, dynamic> json) {
    return AirQualityData(
      co2: json['CO2']?.toDouble() ?? 0.0,
      ammonia: json['Ammonia']?.toDouble() ?? 0.0,
      no2: json['NO2']?.toDouble() ?? 0.0,
      benzene: json['Benzene']?.toDouble() ?? 0.0,
      temperature: json['Temperature']?.toDouble() ?? 0.0,
      humidity: json['Humidity']?.toDouble() ?? 0.0,
      airQuality: json['AirQuality'] ?? "Unknown",
      fan: json['Fan'] ?? "OFF",
      fanMode: json['FanMode'] ?? "AUTO",
      buzzer: json['Buzzer'] ?? "OFF",
      buzzerMode: json['BuzzerMode'] ?? "MANUAL",
      thresholds: Map<String, double>.from(json['Thresholds'].map(
              (key, value) => MapEntry(key, (value as num).toDouble()))),
      timestamp: DateTime.now(),
    );
  }

  // Determine air quality level based on sensor values
  String getAirQualityLevel() {
    // These thresholds are examples - adjust according to your specific needs
    if (co2 > 5000 || ammonia > 10000 || no2 > 1000 || benzene > 1000) {
      return 'Hazardous';
    } else if (co2 > 3000 || ammonia > 7000 || no2 > 600 || benzene > 800) {
      return 'Unhealthy';
    } else if (co2 > 1500 || ammonia > 3000 || no2 > 300 || benzene > 400) {
      return 'Moderate';
    } else {
      return 'Good';
    }
  }

  Color getAirQualityColor() {
    switch (getAirQualityLevel()) {
      case 'Good':
        return Colors.green;
      case 'Moderate':
        return Colors.yellow;
      case 'Unhealthy':
        return Colors.orange;
      case 'Hazardous':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

// State management
final airQualityProvider = StateNotifierProvider<AirQualityNotifier, List<AirQualityData>>((ref) {
  return AirQualityNotifier();
});

class AirQualityNotifier extends StateNotifier<List<AirQualityData>> {
  AirQualityNotifier() : super([]);

  Future<void> fetchData() async {
    try {
      final response = await http.get(Uri.parse('http://192.168.24.94/sensor'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        final AirQualityData data = AirQualityData.fromJson(jsonData);

        // Keep only the last 50 readings for the chart
        if (state.length >= 50) {
          state = [...state.skip(1), data];
        } else {
          state = [...state, data];
        }
      } else {
        throw Exception('Failed to load air quality data');
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
    }
  }
}

// Pages
class HomePage extends ConsumerStatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends ConsumerState<HomePage> {
  Timer? _timer;
  String _selectedParameter = 'CO2';

  @override
  void initState() {
    super.initState();
    // Fetch data immediately
    ref.read(airQualityProvider.notifier).fetchData();

    // Then fetch every 10 seconds
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      ref.read(airQualityProvider.notifier).fetchData();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final airQualityData = ref.watch(airQualityProvider);
    final latestData = airQualityData.isNotEmpty ? airQualityData.last : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Air Quality Monitor'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: latestData == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: () async {
          await ref.read(airQualityProvider.notifier).fetchData();
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              _buildStatusCard(latestData),
              const SizedBox(height: 16),
              _buildParameterSelector(),
              const SizedBox(height: 16),
              _buildChart(airQualityData),
              const SizedBox(height: 16),
              _buildDetailedReadings(latestData),
              const SizedBox(height: 16),
              _buildControlButtons(context), // Add the control buttons here
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await ref.read(airQualityProvider.notifier).fetchData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Updated air quality data')),
            );
          }
        },
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
      ),
    );
  }


  Widget _buildStatusCard(AirQualityData data) {
    final qualityLevel = data.getAirQualityLevel();
    final qualityColor = data.getAirQualityColor();

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Air Quality',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      DateFormat('MMM dd, yyyy - HH:mm').format(data.timestamp),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                Icon(
                  _getAirQualityIcon(qualityLevel),
                  color: qualityColor,
                  size: 48,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              qualityLevel,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: qualityColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getAirQualityDescription(qualityLevel),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParameterSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
              child: Text(
                'Select parameter to display:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildParameterChip('CO2'),
                  _buildParameterChip('Ammonia'),
                  _buildParameterChip('NO2'),
                  _buildParameterChip('Benzene'),
                  _buildParameterChip('Temperature'),
                  _buildParameterChip('Humidity'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParameterChip(String parameter) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Text(parameter),
        selected: _selectedParameter == parameter,
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedParameter = parameter;
            });
          }
        },
      ),
    );
  }

  Widget _buildChart(List<AirQualityData> dataList) {
    if (dataList.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$_selectedParameter Readings Over Time',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() % 5 != 0) return const SizedBox();

                          if (dataList.length > value.toInt() && value.toInt() >= 0) {
                            return Text(
                              DateFormat('HH:mm').format(dataList[value.toInt()].timestamp),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _getSpots(dataList),
                      isCurved: true,
                      color: _getParameterColor(_selectedParameter),
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: true,
                        color: _getParameterColor(_selectedParameter).withOpacity(0.3),
                      ),
                      dotData: FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _getSpots(List<AirQualityData> dataList) {
    return List.generate(dataList.length, (index) {
      final data = dataList[index];
      double value;

      switch (_selectedParameter) {
        case 'CO2':
          value = data.co2;
          break;
        case 'Ammonia':
          value = data.ammonia;
          break;
        case 'NO2':
          value = data.no2;
          break;
        case 'Benzene':
          value = data.benzene;
          break;
        case 'Temperature':
          value = data.temperature;
          break;
        case 'Humidity':
          value = data.humidity;
          break;
        default:
          value = 0;
      }

      return FlSpot(index.toDouble(), value);
    });
  }

  Color _getParameterColor(String parameter) {
    switch (parameter) {
      case 'CO2':
        return Colors.purple;
      case 'Ammonia':
        return Colors.blue;
      case 'NO2':
        return Colors.green;
      case 'Benzene':
        return Colors.orange;
      case 'Temperature':
        return Colors.red;
      case 'Humidity':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Widget _buildDetailedReadings(AirQualityData data) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detailed Readings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildReadingItem('CO2', data.co2, 'ppm', Colors.purple),
            _buildReadingItem('Ammonia', data.ammonia, 'ppb', Colors.blue),
            _buildReadingItem('NO2', data.no2, 'ppb', Colors.green),
            _buildReadingItem('Benzene', data.benzene, 'ppb', Colors.orange),
            _buildReadingItem('Temperature', data.temperature, '°C', Colors.red),
            _buildReadingItem('Humidity', data.humidity, '%', Colors.teal),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingItem(String name, double value, String unit, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(_getParameterDescription(name)),
              ],
            ),
          ),
          Text(
            '${value.toStringAsFixed(1)} $unit',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  IconData _getAirQualityIcon(String qualityLevel) {
    switch (qualityLevel) {
      case 'Good':
        return Icons.emoji_emotions;
      case 'Moderate':
        return Icons.sentiment_satisfied;
      case 'Unhealthy':
        return Icons.sentiment_dissatisfied;
      case 'Hazardous':
        return Icons.warning_amber;
      default:
        return Icons.help_outline;
    }
  }

  String _getAirQualityDescription(String qualityLevel) {
    switch (qualityLevel) {
      case 'Good':
        return 'Air quality is considered satisfactory, and air pollution poses little or no risk.';
      case 'Moderate':
        return 'Air quality is acceptable; however, some pollutants may be of concern for a very small number of individuals.';
      case 'Unhealthy':
        return 'Everyone may begin to experience some adverse health effects, and members of sensitive groups may experience more serious effects.';
      case 'Hazardous':
        return 'Health alert: everyone may experience more serious health effects. Take steps to reduce exposure.';
      default:
        return 'Unable to determine air quality level.';
    }
  }

  String _getParameterDescription(String parameter) {
    switch (parameter) {
      case 'CO2':
        return 'Carbon dioxide level';
      case 'Ammonia':
        return 'Ammonia concentration';
      case 'NO2':
        return 'Nitrogen dioxide level';
      case 'Benzene':
        return 'Benzene concentration';
      case 'Temperature':
        return 'Ambient temperature';
      case 'Humidity':
        return 'Relative humidity';
      default:
        return '';
    }
  }
}

Future<void> controlFan(String action) async {
  String url = 'http://192.168.24.94/$action'; // Replace with your actual IP and endpoints
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final responseBody = json.decode(response.body);
      if (responseBody['status'] == 'success') {
        print('Fan control action $action successful');
      }
    } else {
      throw Exception('Failed to control fan');
    }
  } catch (e) {
    print('Error controlling fan: $e');
  }
}

Future<void> controlBuzzer(String action) async {
  String url = 'http://192.168.24.94/$action'; // Replace with your actual IP and endpoints
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final responseBody = json.decode(response.body);
      if (responseBody['status'] == 'success') {
        print('Buzzer control action $action successful');
      }
    } else {
      throw Exception('Failed to control buzzer');
    }
  } catch (e) {
    print('Error controlling buzzer: $e');
  }
}


Widget _buildControlButtons(BuildContext context) {
  return Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            onPressed: () => _showDeviceControlDialog(context, 'Fan'),
            child: const Text('Fan Control'),
          ),
          ElevatedButton(
            onPressed: () => _showDeviceControlDialog(context, 'Buzzer'),
            child: const Text('Buzzer Control'),
          ),
        ],
      ),
    ],
  );
}

void _showDeviceControlDialog(BuildContext context, String deviceType) {
  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text('$deviceType Controls'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _controlDevice(deviceType, 'on');
              },
              child: Text('Turn $deviceType On'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _controlDevice(deviceType, 'off');
              },
              child: Text('Turn $deviceType Off'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _controlDevice(deviceType, 'auto');
              },
              child: Text('Set $deviceType to Auto'),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _controlDevice(String deviceType, String action) async {
  try {
    if (deviceType == 'Fan') {
      await controlFan('fan/$action');
    } else if (deviceType == 'Buzzer') {
      await controlBuzzer('buzzer/$action');
    }
  } catch (e) {
    // Handle any errors, optionally show a snackbar or print error
    print('Error controlling $deviceType: $e');
  }
}

