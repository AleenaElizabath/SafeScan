import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'models/farmer.dart';
import 'config.dart';

class FarmProfileSetupScreen extends StatefulWidget {
  final Farmer farmer;

  const FarmProfileSetupScreen({
    Key? key,
    required this.farmer,
  }) : super(key: key);

  @override
  State<FarmProfileSetupScreen> createState() => _FarmProfileSetupScreenState();
}

class _FarmProfileSetupScreenState extends State<FarmProfileSetupScreen> {
  late TextEditingController nameController;
  late TextEditingController locationController;
  late TextEditingController cropController;
  late TextEditingController soilController;
  late TextEditingController pesticideController;

  String selectedSeason = 'kharif';

  // 🔥 CHANGE THIS IF USING REAL DEVICE
  // Centralized URL from config.dart
  final String baseUrl = AppConfig.baseUrl;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(text: widget.farmer.name);
    locationController = TextEditingController(text: widget.farmer.location);
    cropController = TextEditingController(text: widget.farmer.cropType);
    soilController = TextEditingController(text: widget.farmer.soilType);
    pesticideController =
        TextEditingController(text: widget.farmer.pesticidesUsed);

    selectedSeason = widget.farmer.season.toLowerCase().replaceAll(' ', '_');
  }

  @override
  void dispose() {
    nameController.dispose();
    locationController.dispose();
    cropController.dispose();
    soilController.dispose();
    pesticideController.dispose();
    super.dispose();
  }

  // ================= BACKEND CONNECTED SAVE =================

  Future<void> _saveProfile() async {
    Farmer updatedFarmer = Farmer(
      id: widget.farmer.id,
      name: nameController.text.trim(),
      location: locationController.text.trim(),
      cropType: cropController.text.trim(),
      soilType: soilController.text.trim(),
      pesticidesUsed: pesticideController.text.trim(),
      season: selectedSeason,
    );

    bool dialogOpen = false;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF00D084),
          ),
        ),
      );
      dialogOpen = true;

      // Backend expects Multipart/Form-Data for farmer profile
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/api/farmer/save_profile"),
      );

      if (updatedFarmer.id != null) {
        request.fields['farmer_id'] = updatedFarmer.id!;
      }
      request.fields['name'] = updatedFarmer.name;
      request.fields['location'] = updatedFarmer.location;
      request.fields['crop_type'] = updatedFarmer.cropType;
      request.fields['soil_type'] = updatedFarmer.soilType;
      request.fields['season'] = updatedFarmer.season;
      request.fields['pesticides_used'] = updatedFarmer.pesticidesUsed;

      // Send request with a 15-second timeout to avoid hanging forever
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw SocketException(
            'Connection timed out. Make sure the backend server is running at $baseUrl',
          );
        },
      );
      var response = await http.Response.fromStream(streamedResponse);

      if (mounted) Navigator.pop(context); // Close loading
      dialogOpen = false;

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        // Backend returns the farmer_id
        Farmer savedFarmer = Farmer(
          id: data['farmer_id'],
          name: updatedFarmer.name,
          location: updatedFarmer.location,
          cropType: updatedFarmer.cropType,
          soilType: updatedFarmer.soilType,
          pesticidesUsed: updatedFarmer.pesticidesUsed,
          season: updatedFarmer.season,
        );
        if (mounted) Navigator.pop(context, savedFarmer);
      } else {
        _showError("Backend Error (${response.statusCode}): ${response.body}");
      }
    } on SocketException catch (e) {
      if (dialogOpen && mounted) Navigator.pop(context);
      _showError(
        "Cannot reach server.\n\n"
        "Please make sure:\n"
        "• The backend is running (uvicorn main:app --host 0.0.0.0 --port 8000)\n"
        "• Your device and PC are on the same Wi-Fi network\n"
        "• The server address is correct: $baseUrl\n\n"
        "Error detail: ${e.message}",
      );
    } catch (e) {
      if (dialogOpen && mounted) Navigator.pop(context);
      _showError("Connection failed: $e");
    }
  }

  // ================= ERROR POPUP =================

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  // ================= UI WIDGETS =================

  Widget _buildTextField(
    String labelKey,
    TextEditingController controller,
    IconData iconData,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelKey.tr(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            prefixIcon: Icon(iconData, color: const Color(0xFF00D084)),
            hintText: "${'enter'.tr()} ${labelKey.tr()}",
            hintStyle: const TextStyle(color: Colors.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF00D084),
                width: 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSeason(String seasonKey, String seasonLabel) {
    bool isSelected = selectedSeason == seasonKey;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedSeason = seasonKey;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF00D084) : Colors.grey.shade300,
            width: isSelected ? 2.5 : 1.5,
          ),
        ),
        child: Text(
          seasonLabel,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: isSelected ? const Color(0xFF00D084) : Colors.grey,
          ),
        ),
      ),
    );
  }

  // ================= MAIN BUILD =================

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
          'setup_profile'.tr(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 30),
              _buildTextField('farmer_name', nameController, Icons.person),
              _buildTextField(
                  'location', locationController, Icons.location_on),
              _buildTextField('crop_type', cropController, Icons.spa),
              _buildTextField('soil_type', soilController, Icons.landscape),
              _buildTextField('current_pesticides', pesticideController,
                  Icons.warning_amber),
              const SizedBox(height: 10),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Select Season",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildSeason('kharif', 'Kharif')),
                  const SizedBox(width: 10),
                  Expanded(child: _buildSeason('rabi', 'Rabi')),
                  const SizedBox(width: 10),
                  Expanded(child: _buildSeason('zaid', 'Zaid')),
                ],
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D084),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'save_profile'.tr(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
