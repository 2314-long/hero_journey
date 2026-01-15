import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dart:math'; // 用于计算最大值

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<dynamic> _history = [];
  bool _isLoading = true;

  // 缓存一些计算后的极值，用于图表归一化
  double _maxGold = 1000;
  double _maxTask = 5;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await ApiService().fetchGrowthHistory();
    if (mounted) {
      setState(() {
        _history = data;
        _isLoading = false;

        // 计算最大值，防止图表顶破天
        if (_history.isNotEmpty) {
          _maxGold = _history
              .map((e) => (e['gold'] as num).toDouble())
              .reduce(max);
          _maxTask = _history
              .map((e) => (e['task_count'] as num).toDouble())
              .reduce(max);
          if (_maxTask == 0) _maxTask = 5; // 避免除以0
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "英雄数据看板",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
          ? _buildEmptyState()
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 1. 顶部概览卡片
                  _buildSummaryCards(),
                  const SizedBox(height: 20),

                  // 2. RPG 核心：能力雷达图
                  _buildRadarChartCard(),
                  const SizedBox(height: 20),

                  // 3. 资产走势 (折线图 - 带交互)
                  _buildLineChartCard(),
                  const SizedBox(height: 20),

                  // 4. 生产力分析 (柱状图)
                  _buildBarChartCard(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  // 📌 顶部概览小卡片
  Widget _buildSummaryCards() {
    int totalTasks = 0;
    int dailyGoldChange = 0;

    if (_history.isNotEmpty) {
      // 1. 计算本周总任务
      totalTasks = _history.fold(
        0,
        (sum, item) => sum + (item['task_count'] as int),
      );

      // 2. 🔥 [修改] 计算较昨日收益
      final todayGold = _history.last['gold'] as int;

      if (_history.length >= 2) {
        // 情况 A: 有两天及以上数据 -> 今天 - 昨天
        final yesterdayGold = _history[_history.length - 2]['gold'] as int;
        dailyGoldChange = todayGold - yesterdayGold;
      } else {
        // 情况 B: 只有今天一天数据 -> 昨天默认为 0
        // 收益 = 今天金币 - 0 = 今天金币
        dailyGoldChange = todayGold;
      }
    }

    // 格式化显示的字符串，如果是正数加个 + 号
    String goldDisplay = dailyGoldChange >= 0
        ? "+$dailyGoldChange"
        : "$dailyGoldChange";

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            "本周任务",
            "$totalTasks",
            Icons.check_circle_outline,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        // 🔥 [修改] 标题改为 "较昨日收益"
        Expanded(
          child: _buildStatCard(
            "较昨日收益",
            goldDisplay,
            Icons.trending_up,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🕸️ 英雄能力雷达图
  Widget _buildRadarChartCard() {
    // 构造雷达数据 (模拟 RPG 属性)
    // 这里的逻辑是：将真实数据映射到 0-5 的评分上
    if (_history.isEmpty) return const SizedBox.shrink();

    final lastLog = _history.last;

    // 简单的评分算法 (你可以根据游戏数值调整)
    double wealthScore = min(
      (lastLog['gold'] as int) / 5000 * 4,
      5,
    ); // 假设 5000 金币算及格
    double diligenceScore = min(
      (lastLog['task_count'] as int) / 5 * 5,
      5,
    ); // 每天5个任务算满分
    double enduranceScore = min(
      (lastLog['active_days'] as int) / 7 * 5,
      5,
    ); // 连续7天算满分

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "能力五维图",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Icon(Icons.pentagon_outlined, color: Colors.indigoAccent),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: RadarChart(
              RadarChartData(
                dataSets: [
                  RadarDataSet(
                    fillColor: Colors.indigo.withOpacity(0.2),
                    borderColor: Colors.indigo,
                    entryRadius: 3,
                    dataEntries: [
                      RadarEntry(value: wealthScore),
                      RadarEntry(value: diligenceScore),
                      RadarEntry(value: enduranceScore),
                      RadarEntry(value: 3.0), // 智力 (暂时Mock)
                      RadarEntry(value: 4.0), // 幸运 (暂时Mock)
                    ],
                  ),
                ],
                radarBackgroundColor: Colors.transparent,
                borderData: FlBorderData(show: false),
                radarBorderData: const BorderSide(color: Colors.transparent),
                titlePositionPercentageOffset: 0.2,
                titleTextStyle: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
                tickCount: 1,
                tickBorderData: const BorderSide(color: Colors.transparent),
                ticksTextStyle: const TextStyle(color: Colors.transparent),
                gridBorderData: BorderSide(
                  color: Colors.grey.shade200,
                  width: 2,
                ),
                getTitle: (index, angle) {
                  switch (index) {
                    case 0:
                      return const RadarChartTitle(text: '财富');
                    case 1:
                      return const RadarChartTitle(text: '勤奋');
                    case 2:
                      return const RadarChartTitle(text: '毅力');
                    case 3:
                      return const RadarChartTitle(text: '智力');
                    case 4:
                      return const RadarChartTitle(text: '幸运');
                    default:
                      return const RadarChartTitle(text: '');
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 📈 金币资产走势 (Line Chart)
  Widget _buildLineChartCard() {
    List<FlSpot> spots = [];
    for (int i = 0; i < _history.length; i++) {
      spots.add(FlSpot(i.toDouble(), (_history[i]['gold'] as int).toDouble()));
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade50, Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "财富积累趋势",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.brown,
            ),
          ),
          const SizedBox(height: 20),
          AspectRatio(
            aspectRatio: 1.70,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.orange.withOpacity(0.1),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < _history.length) {
                          // 解析日期字符串 "2023-10-25" -> "10/25"
                          String date = _history[index]['log_date'];
                          List<String> parts = date.split('-');
                          if (parts.length >= 3)
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                "${parts[1]}/${parts[2]}",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            );
                        }
                        return const Text("");
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const Text("");
                        return Text(
                          value >= 1000
                              ? "${(value / 1000).toStringAsFixed(1)}k"
                              : value.toInt().toString(),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => Colors.orange,
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        return LineTooltipItem(
                          '${barSpot.y.toInt()} G',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.orange,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.orange.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 📊 每日任务完成 (Bar Chart) - 数字常驻显示版
  Widget _buildBarChartCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "每日战斗力 (完成任务)",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 40), // 🔥 增加顶部间距，给数字腾出位置
          AspectRatio(
            aspectRatio: 1.7,
            child: BarChart(
              BarChartData(
                // 1. 🔥 关闭触摸交互，改用常驻显示
                barTouchData: BarTouchData(
                  enabled: false, // 禁止触摸变色，因为我们要一直显示
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => Colors.transparent, // 🔥 背景透明
                    tooltipPadding: EdgeInsets.zero,
                    tooltipMargin: 4, // 数字距离柱子的距离
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        rod.toY.toInt().toString(),
                        TextStyle(
                          color: rod.toY >= 3
                              ? Colors.blue
                              : Colors.blue.shade300, // 字体颜色
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),

                // ... 坐标轴配置保持不变 ...
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < _history.length) {
                          String date = _history[index]['log_date'];
                          List<String> parts = date.split('-');
                          if (parts.length >= 3)
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                parts[2],
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                        }
                        return const Text("");
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),

                // 2. 🔥 数据组配置
                barGroups: _history.asMap().entries.map((entry) {
                  int index = entry.key;
                  int tasks = entry.value['task_count'] ?? 0;

                  return BarChartGroupData(
                    x: index,
                    // 🔥 [核心] 强制显示 Tooltip (也就是我们的数字)
                    showingTooltipIndicators: [0],
                    barRods: [
                      BarChartRodData(
                        toY: tasks.toDouble(),
                        color: tasks >= 3 ? Colors.blue : Colors.blue.shade200,
                        width: 16,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 10,
                          color: Colors.grey.shade100,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    // 保持原来的 Empty State 代码
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.analytics_outlined, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text("暂无战斗数据", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          Text(
            "去完成几个任务，明天来看结果！",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}
