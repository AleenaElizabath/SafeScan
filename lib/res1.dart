import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'scan.dart';
import 'profile.dart';
import 'models/farmer.dart';
import 'config.dart';

class PestAnalysisScreen extends StatefulWidget {
  final Farmer farmer;
  final File? image;

  const PestAnalysisScreen({
    Key? key,
    required this.farmer,
    this.image,
  }) : super(key: key);

  @override
  State<PestAnalysisScreen> createState() => _PestAnalysisScreenState();
}

class _PestAnalysisScreenState extends State<PestAnalysisScreen> {
  int currentNavIndex = 0;
  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? analysisResult;

  final String baseUrl = AppConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _performAnalysis();
  }

  Future<void> _performAnalysis() async {
    if (widget.image == null) {
      setState(() {
        isLoading = false;
        errorMessage = "No image selected";
      });
      return;
    }

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/api/pesticide/analyze"),
      );

      // Add image file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          widget.image!.path,
        ),
      );

      // Add farmer context if available
      if (widget.farmer.id != null) {
        request.fields['farmer_id'] = widget.farmer.id!;
      }
      request.fields['name'] = widget.farmer.name;
      request.fields['crop_type'] = widget.farmer.cropType;
      request.fields['location'] = widget.farmer.location;
      request.fields['season'] = widget.farmer.season;

      // 30-second timeout — pesticide analysis is AI-heavy
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw SocketException(
            'Connection timed out. Make sure the backend is running at $baseUrl',
          );
        },
      );
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        if (mounted) {
          final decoded = jsonDecode(response.body);
          if (decoded['success'] == true) {
            setState(() {
              analysisResult = decoded;
              isLoading = false;
            });
          } else {
            setState(() {
              errorMessage = decoded['message'] ??
                  "Analysis failed (backend reported failure)";
              isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            errorMessage =
                "Analysis Failed (${response.statusCode}): ${response.body}";
            isLoading = false;
          });
        }
      }
    } on SocketException catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = "Cannot reach server.\n\n"
              "Make sure:\n"
              "• Backend is running: uvicorn main:app --host 0.0.0.0 --port 8000\n"
              "• Device and PC are on the same Wi-Fi\n"
              "• Server address: $baseUrl\n\n"
              "Detail: ${e.message}";
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = "Connection Error: $e";
          isLoading = false;
        });
      }
    }
  }

  void _onNavTap(int index) {
    if (index == currentNavIndex) return;
    setState(() {
      currentNavIndex = index;
    });
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ScanScreen()),
      );
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => FarmProfileSetupScreen(farmer: widget.farmer)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'pesticide_analysis'.tr(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? _buildLoadingState()
          : errorMessage != null
              ? _buildErrorState()
              : _buildResultContent(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentNavIndex,
        onTap: _onNavTap,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
              icon: const Icon(Icons.qr_code_scanner), label: 'scan'.tr()),
          BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline), label: 'profile'.tr()),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF00D084)),
          const SizedBox(height: 20),
          Text(
            "Analyzing Pesticide Label...",
            style: TextStyle(
                color: Colors.grey.shade700, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Checking regulatory status, toxicity, and generating personalized advice using Gemini AI...",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
            const SizedBox(height: 20),
            Text(errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  isLoading = true;
                  errorMessage = null;
                });
                _performAnalysis();
              },
              child: const Text("Retry"),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildResultContent() {
    if (analysisResult == null) return const SizedBox();

    // Support both nested result or flat result for robustness
    final result = (analysisResult!['result'] != null)
        ? analysisResult!['result'] as Map<String, dynamic>
        : analysisResult!;

    final summary = result['summary'] ?? {};
    final isBanned = summary['is_banned'] ?? false;
    final riskCategory = result['risk_category'] ?? "UNKNOWN";
    final urgency = result['urgency_level'] ?? "LOW";

    Color urgencyColor = Colors.green;
    if (urgency == "CRITICAL") {
      urgencyColor = Colors.red.shade700;
    } else if (urgency == "HIGH")
      urgencyColor = Colors.orange.shade800;
    else if (urgency == "MEDIUM") urgencyColor = Colors.orange.shade400;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Urgency Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: urgencyColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: urgencyColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: urgencyColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "RISK LEVEL: $riskCategory",
                    style: TextStyle(
                        color: urgencyColor, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  urgency,
                  style: TextStyle(
                      color: urgencyColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 12),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Main Personalized Warning Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_pin, color: Color(0xFF00D084)),
                    const SizedBox(width: 8),
                    Text(
                      "Personalized Advice",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blueGrey.shade800),
                    ),
                    const Spacer(),
                    if (result['ai_powered'] == true)
                      Icon(Icons.auto_awesome,
                          size: 16, color: Colors.purple.shade300),
                  ],
                ),
                const Divider(height: 24),
                Text(
                  result['personalized_warning'] ?? "Analysis complete.",
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Toxicity & Environment Info
          Row(
            children: [
              Expanded(
                  child: _buildInfoSmallCard(
                      "Toxicity",
                      summary['toxicity'] ?? "N/A",
                      Icons.opacity,
                      Colors.deepOrange)),
              const SizedBox(width: 15),
              Expanded(
                  child: _buildInfoSmallCard(
                      "Status",
                      summary['status'] ?? "N/A",
                      Icons.gavel,
                      isBanned ? Colors.red : Colors.green)),
            ],
          ),

          const SizedBox(height: 20),

          // Alternatives Section
          Text(
            "Eco-Friendly Alternatives",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.blueGrey.shade900),
          ),
          const SizedBox(height: 10),
          ...((result['eco_friendly_alternatives'] as List? ?? [])
              .map((alt) => _buildAlternativeCard(alt))
              .toList()),

          const SizedBox(height: 20),

          // Side Effects Section
          Text(
            "Health & Environment Risks",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.blueGrey.shade900),
          ),
          const SizedBox(height: 10),
          _buildSideEffectsCard(result),

          const SizedBox(height: 30),

          // New Scan Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D084),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text("PROCEED WITH CAUTION",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.black)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildInfoSmallCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13, color: color)),
        ],
      ),
    );
  }

  Widget _buildAlternativeCard(Map<String, dynamic> alt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF00D084).withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF00D084).withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.eco, color: Colors.green, size: 18),
              const SizedBox(width: 8),
              Text(alt['name'] ?? "Alternative",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 6),
          Text(alt['why_suitable'] ?? "",
              style: const TextStyle(fontSize: 12, color: Colors.black87)),
          const SizedBox(height: 8),
          Text(
            "Application: ${alt['application']}",
            style: TextStyle(
                fontSize: 11,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSideEffectsCard(Map<String, dynamic> result) {
    final human = result['side_effects_humans'] ?? {};
    final env = result['side_effects_environment'] ?? {};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          _buildExpandableRow(
              "Applicator Risks", human['applicator_risks'] ?? ""),
          _buildExpandableRow("Soil Impact", env['soil_impact'] ?? ""),
          _buildExpandableRow("Water Impact", env['water_impact'] ?? ""),
          _buildExpandableRow(
              "Beneficial Insects", env['beneficial_organisms'] ?? ""),
        ],
      ),
    );
  }

  Widget _buildExpandableRow(String title, String content) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(content,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const Divider(height: 20),
        ],
      ),
    );
  }
}
