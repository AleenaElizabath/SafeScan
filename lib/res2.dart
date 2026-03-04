import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'scan.dart';
import 'profile.dart';
import 'models/farmer.dart';
import 'config.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DiagnosisResultScreen extends StatefulWidget {
  final Farmer farmer;
  final File? image;

  const DiagnosisResultScreen({
    Key? key,
    required this.farmer,
    this.image,
  }) : super(key: key);

  @override
  State<DiagnosisResultScreen> createState() => _DiagnosisResultScreenState();
}

class _DiagnosisResultScreenState extends State<DiagnosisResultScreen> {
  int currentNavIndex = 0;
  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? analysisResult;

  final String baseUrl = AppConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _performDiagnosis();
  }

  Future<void> _performDiagnosis() async {
    if (widget.image == null) {
      setState(() {
        isLoading = false;
        errorMessage = "No image selected";
      });
      return;
    }

    if (widget.farmer.id == null) {
      setState(() {
        isLoading = false;
        errorMessage = "Farmer Profile Missing. Please setup profile first.";
      });
      return;
    }

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/api/plant_disease/detect"),
      );

      request.files.add(
        await http.MultipartFile.fromPath('file', widget.image!.path),
      );
      request.fields['farmer_id'] = widget.farmer.id!;

      // 30-second timeout — plant disease analysis is AI-heavy
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
          setState(() {
            analysisResult = jsonDecode(response.body);
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            errorMessage =
                "Diagnosis Failed (${response.statusCode}):\n${response.body}";
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
    setState(() => currentNavIndex = index);
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

  // ─────────────────────────────────────────────────────────────────────────
  // SCAFFOLD
  // ─────────────────────────────────────────────────────────────────────────

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
          'diagnosis_result'.tr(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          if (analysisResult?['result']?['ai_powered'] == true)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Icon(Icons.auto_awesome,
                  size: 20, color: Colors.purple.shade400),
            ),
        ],
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

  // ─────────────────────────────────────────────────────────────────────────
  // LOADING / ERROR
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF00D084)),
          const SizedBox(height: 20),
          Text(
            "Analyzing Plant Health...",
            style: TextStyle(
                color: Colors.grey.shade700, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Detecting disease and generating personalized watering, nutrient & treatment advice...",
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
            if (!errorMessage!.contains("Profile"))
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    isLoading = true;
                    errorMessage = null;
                  });
                  _performDiagnosis();
                },
                child: const Text("Retry"),
              )
            else
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            FarmProfileSetupScreen(farmer: widget.farmer)),
                  );
                },
                child: const Text("Setup Profile"),
              )
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MAIN RESULT
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildResultContent() {
    if (analysisResult == null || analysisResult!['result'] == null) {
      return const SizedBox();
    }

    final result = analysisResult!['result'] as Map<String, dynamic>;
    final summary = result['summary'] as Map<String, dynamic>? ?? {};
    final diseaseName = result['detected_disease'] ?? "Unknown";
    final severity = summary['severity'] ?? "Unknown";
    final confidenceRaw = result['confidence'];
    final confidence = (confidenceRaw is num) ? confidenceRaw.toDouble() : 0.0;
    final aiPowered = result['ai_powered'] == true;

    Color severityColor = Colors.green;
    if (severity == "High") {
      severityColor = Colors.red.shade700;
    } else if (severity == "Medium")
      severityColor = Colors.orange.shade700;
    else if (severity == "None") severityColor = Colors.green.shade600;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Disease Header Card ────────────────────────────────────────────
          _buildDiseaseHeaderCard(
              diseaseName, severity, confidence, aiPowered, severityColor),

          const SizedBox(height: 16),

          // ── Personalized Note ──────────────────────────────────────────────
          if ((result['personalized_note'] as String? ?? '').isNotEmpty)
            _buildNoteCard(result['personalized_note'] as String),

          const SizedBox(height: 16),

          // ── Disease Explanation ────────────────────────────────────────────
          if ((result['disease_explanation'] as String? ?? '').isNotEmpty) ...[
            _buildSectionTitle("What's Happening?", Icons.info_outline,
                Colors.blueGrey.shade700),
            const SizedBox(height: 8),
            _buildTextCard(result['disease_explanation'] as String),
            const SizedBox(height: 20),
          ],

          // ── Immediate Action ───────────────────────────────────────────────
          _buildSectionTitle(
              "Immediate Action", Icons.flash_on, Colors.deepOrange),
          const SizedBox(height: 8),
          _buildTextCard(
            summary['immediate_action'] ?? "Consult agricultural expert",
            borderColor: Colors.deepOrange.shade300,
          ),

          const SizedBox(height: 20),

          // ── Watering Advice ────────────────────────────────────────────────
          if ((result['watering_advice'] as Map?)?.isNotEmpty == true) ...[
            _buildSectionTitle(
                "Watering Advice", Icons.water_drop, Colors.blue.shade700),
            const SizedBox(height: 8),
            _buildWateringCard(
                result['watering_advice'] as Map<String, dynamic>),
            const SizedBox(height: 20),
          ],

          // ── Nutrient Plan ──────────────────────────────────────────────────
          if ((result['nutrient_plan'] as Map?)?.isNotEmpty == true) ...[
            _buildSectionTitle(
                "Nutrient & Fertilizer Plan", Icons.science, Colors.teal),
            const SizedBox(height: 8),
            _buildNutrientCard(result['nutrient_plan'] as Map<String, dynamic>),
            const SizedBox(height: 20),
          ],

          // ── Treatment Steps ────────────────────────────────────────────────
          if ((result['treatment_steps'] as List?)?.isNotEmpty == true) ...[
            _buildSectionTitle(
                "Treatment Steps", Icons.medical_services, Colors.red.shade700),
            const SizedBox(height: 8),
            _buildTreatmentStepsCard(
                (result['treatment_steps'] as List).cast<String>()),
            const SizedBox(height: 20),
          ],

          // ── Eco-Friendly Solutions ─────────────────────────────────────────
          if ((result['eco_friendly_solutions'] as List?)?.isNotEmpty ==
              true) ...[
            _buildSectionTitle(
                "Eco-Friendly Solutions", Icons.eco, Colors.green.shade700),
            const SizedBox(height: 8),
            ...(result['eco_friendly_solutions'] as List)
                .map(
                    (sol) => _buildEcoSolutionCard(sol as Map<String, dynamic>))
                .toList(),
            const SizedBox(height: 20),
          ],

          // ── Changes from Current State ─────────────────────────────────────
          if ((result['changes_from_current'] as List?)?.isNotEmpty ==
              true) ...[
            _buildSectionTitle("Changes to Make Now",
                Icons.change_circle_outlined, Colors.orange.shade800),
            const SizedBox(height: 8),
            _buildBulletListCard(
                (result['changes_from_current'] as List).cast<String>(),
                Icons.arrow_forward_ios,
                Colors.orange.shade700),
            const SizedBox(height: 20),
          ],

          // ── Prevention Tips ────────────────────────────────────────────────
          if ((result['prevention_tips'] as List?)?.isNotEmpty == true) ...[
            _buildSectionTitle(
                "Prevention Tips", Icons.shield_outlined, Colors.indigo),
            const SizedBox(height: 8),
            _buildBulletListCard(
                (result['prevention_tips'] as List).cast<String>(),
                Icons.check_circle_outline,
                Colors.indigo),
            const SizedBox(height: 20),
          ],

          // ── AI-powered badge ───────────────────────────────────────────────
          if (aiPowered)
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome,
                      size: 14, color: Colors.purple.shade300),
                  const SizedBox(width: 6),
                  Text(
                    "Personalized by Gemini AI",
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.purple.shade300,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          // ── New Scan Button ────────────────────────────────────────────────
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
              child: const Text("START NEW SCAN",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.blueGrey.shade900),
        ),
      ],
    );
  }

  Widget _buildDiseaseHeaderCard(String diseaseName, String severity,
      double confidence, bool aiPowered, Color severityColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${severity.toUpperCase()} SEVERITY",
                  style: TextStyle(
                      color: severityColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10),
                ),
              ),
              if (aiPowered) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome,
                          size: 10, color: Colors.purple.shade400),
                      const SizedBox(width: 4),
                      Text("AI",
                          style: TextStyle(
                              color: Colors.purple.shade400,
                              fontWeight: FontWeight.bold,
                              fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 15),
          Text(
            diseaseName,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 8),
          Text(
            "Confidence: ${confidence.toStringAsFixed(1)}%",
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(String note) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF00D084).withOpacity(0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF00D084).withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.person_pin, color: Color(0xFF00D084), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              note,
              style: const TextStyle(
                  fontSize: 13, height: 1.5, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextCard(String text, {Color? borderColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border:
            Border.all(color: (borderColor ?? Colors.grey).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, height: 1.6),
      ),
    );
  }

  Widget _buildWateringCard(Map<String, dynamic> advice) {
    final tips = (advice['tips'] as List? ?? []).cast<String>();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blue.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((advice['current_issue'] as String? ?? '').isNotEmpty)
            _infoRow(Icons.warning_amber_outlined, Colors.orange.shade700,
                "Current Issue", advice['current_issue'] as String),
          if ((advice['recommended_schedule'] as String? ?? '').isNotEmpty)
            _infoRow(Icons.calendar_today_outlined, Colors.blue.shade700,
                "Schedule", advice['recommended_schedule'] as String),
          if ((advice['method'] as String? ?? '').isNotEmpty)
            _infoRow(Icons.opacity, Colors.blue.shade700, "Method",
                advice['method'] as String),
          if (tips.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text("Tips:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            ...tips.map((tip) => _bulletRow(tip, Colors.blue.shade600)),
          ],
        ],
      ),
    );
  }

  Widget _buildNutrientCard(Map<String, dynamic> plan) {
    final fertilizers =
        (plan['fertilizers'] as List? ?? []).cast<Map<String, dynamic>>();
    final organic = (plan['organic_options'] as List? ?? []).cast<String>();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.teal.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((plan['deficiency_note'] as String? ?? '').isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.teal.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    plan['deficiency_note'] as String,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.teal.shade800,
                        fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (fertilizers.isNotEmpty) ...[
            const Text("Recommended Fertilizers:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 8),
            ...fertilizers.map((f) => _buildFertilizerRow(f)),
          ],
          if (organic.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text("Organic Options:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            ...organic.map((o) => _bulletRow(o, Colors.green.shade700)),
          ],
        ],
      ),
    );
  }

  Widget _buildFertilizerRow(Map<String, dynamic> f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(f['name'] ?? '',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.scale, size: 12, color: Colors.grey),
            const SizedBox(width: 4),
            Text("${f['dose']}  •  ${f['frequency']}",
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
          const SizedBox(height: 4),
          Text(f['reason'] ?? '',
              style: TextStyle(fontSize: 11, color: Colors.teal.shade700)),
        ],
      ),
    );
  }

  Widget _buildTreatmentStepsCard(List<String> steps) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        children: List.generate(steps.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: Colors.red.shade700,
                  child: Text(
                    "${i + 1}",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    // Strip "Step N: " prefix if Gemini/fallback included it
                    steps[i].replaceFirst(RegExp(r'^Step \d+:\s*'), ''),
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEcoSolutionCard(Map<String, dynamic> sol) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.green.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.eco, color: Colors.green, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sol['name'] ?? "Solution",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              if ((sol['frequency'] as String? ?? '').isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    sol['frequency'] as String,
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          if ((sol['how_to_apply'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              sol['how_to_apply'] as String,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBulletListCard(List<String> items, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        children: items
            .map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: color, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(item,
                              style:
                                  const TextStyle(fontSize: 13, height: 1.4))),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ── Shared helpers ──────────────────────────────────────────────────────

  Widget _infoRow(IconData icon, Color color, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                      text: "$label: ",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.blueGrey.shade800)),
                  TextSpan(
                      text: value,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black87)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulletRow(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 6, color: color),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 12, height: 1.4))),
        ],
      ),
    );
  }
}
