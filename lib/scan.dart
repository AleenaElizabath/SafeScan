import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'res1.dart';
import 'res2.dart';
import 'profile.dart';
import 'models/farmer.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({Key? key}) : super(key: key);

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  String selectedTab = 'pesticide_mode';
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  Farmer farmer = Farmer(
    name: "",
    location: "",
    cropType: "",
    soilType: "",
    pesticidesUsed: "",
    season: "Kharif",
  );

  // 🔥 Open profile and receive updated data
  Future<void> _openProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FarmProfileSetupScreen(farmer: farmer),
      ),
    );

    if (result != null && result is Farmer) {
      setState(() {
        farmer = result;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile =
    await _picker.pickImage(source: source, imageQuality: 85);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  void _showImageSourceOptions() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'select_image_source'.tr(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Color(0xFF00D084)),
                  title: Text('capture_camera'.tr()),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo, color: Color(0xFF00D084)),
                  title: Text('choose_gallery'.tr()),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _analyzeImage() {
    if (_selectedImage == null) return;

    if (selectedTab == 'pesticide_mode') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PestAnalysisScreen(
            farmer: farmer,
            image: _selectedImage,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DiagnosisResultScreen(
            farmer: farmer,
            image: _selectedImage,
          ),
        ),
      );
    }
  }

  // 🌱 Farmer Info Card with improved design
  Widget _buildFarmerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'farmer_profile'.tr(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          _infoRow('name'.tr(), farmer.name),
          _infoRow('location'.tr(), farmer.location),
          _infoRow('crop'.tr(), farmer.cropType),
          _infoRow('soil'.tr(), farmer.soilType),
          _infoRow('pesticides'.tr(), farmer.pesticidesUsed),
          _infoRow('season'.tr(), farmer.season),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            "$label: ",
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'not_set'.tr() : value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🟢 Mode Selector with improved design
  Widget _buildModeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _modeButton('pesticide_mode'.tr(), 'pesticide_mode'),
          _modeButton('plant_health_mode'.tr(), 'plant_health_mode'),
        ],
      ),
    );
  }

  Widget _modeButton(String label, String modeValue) {
    bool isSelected = selectedTab == modeValue;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedTab = modeValue;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00D084) : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected ? Colors.black : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Column(
      children: [
        Container(
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF00D084), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              _selectedImage!,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _analyzeImage,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00D084),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            elevation: 6,
          ),
          child: Text(
            'analyze_now'.tr(),
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }

  // 🌐 Language Switcher
  Widget _buildLanguageButton() {
    return PopupMenuButton<Locale>(
      icon: const Icon(Icons.language, color: Colors.white, size: 24),
      onSelected: (Locale locale) {
        context.setLocale(locale);
      },
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem<Locale>(
          value: Locale('en', 'US'),
          child: Text('English'),
        ),
        const PopupMenuItem<Locale>(
          value: Locale('hi', 'IN'),
          child: Text('हिन्दी'),
        ),
        const PopupMenuItem<Locale>(
          value: Locale('ml', 'IN'),
          child: Text('മലയാളം'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image:
                AssetImage('assets/bg1.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          Container(
              color:
              Colors.black.withOpacity(
                  0.45)),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Top Bar with language selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'app_subtitle'.tr(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Row(
                        children: [
                          _buildLanguageButton(),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _openProfile,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.white,
                                child: Icon(
                                  Icons.person,
                                  color: Color(0xFF00D084),
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  _buildFarmerCard(),

                  const SizedBox(height: 25),

                  _buildModeSelector(),

                  const Spacer(),

                  if (_selectedImage != null) ...[
                    _buildImagePreview(),
                    const SizedBox(height: 20),
                  ],

                  GestureDetector(
                    onTap: _showImageSourceOptions,
                    child: Container(
                      width: 75,
                      height: 75,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Color(0xFF00D084),
                        size: 36,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
