import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/utils/constants.dart';

class CreateReportScreen extends StatefulWidget {
  const CreateReportScreen({super.key});

  @override
  State<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends State<CreateReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  
  File? _capturedImage;
  Position? _currentLocation;
  bool _isProcessing = false;
  bool _locationPermissionGranted = false;
  bool _cameraPermissionGranted = false;
  
  List<String> _approvedLoanItems = [];
  String? _matchedItem;
  double _trustScore = 0.0;
  
  // Mock dataset of loan items with keywords
  final Map<String, List<String>> _loanItemKeywords = {
    'Tractor': ['tractor', 'vehicle', 'farm', 'machine', 'wheel', 'agriculture'],
    'Irrigation Pump': ['pump', 'water', 'irrigation', 'motor', 'pipe'],
    'Seeds': ['seed', 'packet', 'bag', 'grain', 'plant'],
    'Dairy Equipment': ['dairy', 'milk', 'equipment', 'steel', 'container'],
    'Cattle Feed': ['feed', 'cattle', 'bag', 'sack', 'fodder'],
    'Milking Machine': ['milking', 'machine', 'dairy', 'equipment', 'automated'],
    'Fertilizer': ['fertilizer', 'bag', 'chemical', 'nutrients', 'urea'],
    'Solar Panel': ['solar', 'panel', 'electricity', 'renewable', 'energy'],
  };

  @override
  void initState() {
    super.initState();
    _loadApprovedLoanItems();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadApprovedLoanItems() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _approvedLoanItems = prefs.getStringList('approved_loan_items') ?? [];
    });
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    
    if (status.isGranted) {
      setState(() => _locationPermissionGranted = true);
      await _getCurrentLocation();
    } else if (status.isDenied) {
      _showPermissionDialog(
        'Location Permission Required',
        'Please grant location permission to verify the report location.',
        Permission.location,
      );
    } else if (status.isPermanentlyDenied) {
      _showSettingsDialog('Location');
    }
  }
  Future<void> _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _capturedImage = File(image.path);
        });

        // Process image with AI model (simulated)
        await _processImageWithAI();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image selected and analyzed'),
              backgroundColor: AppColors.successColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select image: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }


  Future<void> _getCurrentLocation() async {
    try {
      setState(() => _isProcessing = true);
      
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled';
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = position;
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location captured successfully'),
            backgroundColor: AppColors.successColor,
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get location: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    
    if (status.isGranted) {
      setState(() => _cameraPermissionGranted = true);
      await _captureImage();
    } else if (status.isDenied) {
      _showPermissionDialog(
        'Camera Permission Required',
        'Please grant camera permission to capture images for verification.',
        Permission.camera,
      );
    } else if (status.isPermanentlyDenied) {
      _showSettingsDialog('Camera');
    }
  }

  Future<void> _captureImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _capturedImage = File(image.path);
        });
        
        // Process image with AI model (simulated)
        await _processImageWithAI();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image captured and analyzed'),
              backgroundColor: AppColors.successColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to capture image: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _processImageWithAI() async {
    setState(() => _isProcessing = true);
    
    // Simulate AI processing delay
    await Future.delayed(const Duration(seconds: 2));
    
    // Simulate image-to-text matching with approved loan items
    // In real implementation, this would call an AI model API
    final random = Random();
    
    if (_approvedLoanItems.isNotEmpty) {
      // Simulate matching with approved items
      final matchIndex = random.nextInt(_approvedLoanItems.length);
      _matchedItem = _approvedLoanItems[matchIndex];
      
      // Calculate trust score based on:
      // 1. Image quality simulation (70-95%)
      // 2. Location verification (if available, +5%)
      // 3. Time of day appropriateness (+0-5%)
      
      double baseScore = 0.70 + (random.nextDouble() * 0.25); // 70-95%
      
      if (_currentLocation != null) {
        baseScore += 0.05; // Bonus for location verification
      }
      
      _trustScore = baseScore.clamp(0.0, 1.0);
      
      // Set pre-filled description
      _descriptionController.text = 
          'Verification photo for $_matchedItem captured on ${_formatDate(DateTime.now())}';
    } else {
      _matchedItem = null;
      _trustScore = 0.0;
    }
    
    setState(() => _isProcessing = false);
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_capturedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture an image first'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }
    
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable location for verification'),
          backgroundColor: AppColors.warningColor,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final reportCount = prefs.getInt('report_count') ?? 0;
      final newReportId = reportCount;
      
      // Save report data
      await prefs.setInt('report_${newReportId}_id', newReportId);
      await prefs.setString('report_${newReportId}_itemName', _matchedItem ?? 'Unknown Item');
      await prefs.setString('report_${newReportId}_description', _descriptionController.text);
      await prefs.setDouble('report_${newReportId}_trustScore', _trustScore);
      await prefs.setString('report_${newReportId}_status', 'pending');
      await prefs.setInt('report_${newReportId}_timestamp', DateTime.now().millisecondsSinceEpoch);
      await prefs.setString('report_${newReportId}_imagePath', _capturedImage!.path);
      await prefs.setDouble('report_${newReportId}_latitude', _currentLocation!.latitude);
      await prefs.setDouble('report_${newReportId}_longitude', _currentLocation!.longitude);
      
      await prefs.setInt('report_count', reportCount + 1);
      
      // Also save to authority queue
      final authorityReportCount = prefs.getInt('authority_report_count') ?? 0;
      await prefs.setInt('authority_report_${authorityReportCount}_id', newReportId);
      await prefs.setString('authority_report_${authorityReportCount}_itemName', _matchedItem ?? 'Unknown Item');
      await prefs.setString('authority_report_${authorityReportCount}_description', _descriptionController.text);
      await prefs.setDouble('authority_report_${authorityReportCount}_trustScore', _trustScore);
      await prefs.setString('authority_report_${authorityReportCount}_status', 'pending');
      await prefs.setInt('authority_report_${authorityReportCount}_timestamp', DateTime.now().millisecondsSinceEpoch);
      await prefs.setString('authority_report_${authorityReportCount}_imagePath', _capturedImage!.path);
      await prefs.setDouble('authority_report_${authorityReportCount}_latitude', _currentLocation!.latitude);
      await prefs.setDouble('authority_report_${authorityReportCount}_longitude', _currentLocation!.longitude);
      await prefs.setString('authority_report_${authorityReportCount}_userName', prefs.getString('user_name') ?? 'Unknown');
      await prefs.setString('authority_report_${authorityReportCount}_userPhone', prefs.getString('user_phone') ?? '');
      
      await prefs.setInt('authority_report_count', authorityReportCount + 1);

      setState(() => _isProcessing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted successfully'),
            backgroundColor: AppColors.successColor,
          ),
        );
        
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit report: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  void _showPermissionDialog(String title, String message, Permission permission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              permission.request();
            },
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(String permissionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permissionName Permission Denied'),
        content: Text(
          'Please enable $permissionName permission from settings to use this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Report'),
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildInfoCard(),
                    const SizedBox(height: 24),
                    _buildLocationSection(),
                    const SizedBox(height: 24),
                    _buildCameraSection(),
                    const SizedBox(height: 24),
                    if (_matchedItem != null) ...[
                      _buildAIResultSection(),
                      const SizedBox(height: 24),
                    ],
                    _buildDescriptionSection(),
                    const SizedBox(height: 32),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.infoColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.infoColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: AppColors.infoColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Capture a clear photo of the loan item at the actual location for verification',
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _currentLocation != null 
                      ? Icons.location_on 
                      : Icons.location_off,
                  color: _currentLocation != null 
                      ? AppColors.successColor 
                      : AppColors.errorColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Location Verification',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_currentLocation != null) ...[
              Text(
                'Latitude: ${_currentLocation!.latitude.toStringAsFixed(6)}',
                style: AppTextStyles.bodySmall.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                'Longitude: ${_currentLocation!.longitude.toStringAsFixed(6)}',
                style: AppTextStyles.bodySmall.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppColors.successColor,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Location captured',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.successColor,
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                'Location is required for report verification',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _requestLocationPermission,
              icon: const Icon(Icons.my_location),
              label: Text(_currentLocation != null 
                  ? 'Update Location' 
                  : 'Enable Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentLocation != null 
                    ? AppColors.successColor 
                    : AppColors.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _requestCameraPermission,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(_capturedImage != null ? 'Retake Photo' : 'Capture Photo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _capturedImage != null
                          ? AppColors.successColor
                          : AppColors.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickImageFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Upload from Gallery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            if (_capturedImage != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _capturedImage!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey.shade400,
                    style: BorderStyle.solid,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo,
                        size: 48,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No photo captured',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            ElevatedButton.icon(
              onPressed: _requestCameraPermission,
              icon: const Icon(Icons.camera_alt),
              label: Text(_capturedImage != null 
                  ? 'Retake Photo' 
                  : 'Capture Photo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _capturedImage != null 
                    ? AppColors.successColor 
                    : AppColors.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIResultSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.psychology,
                  color: AppColors.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'AI Analysis Result',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildResultRow('Matched Item', _matchedItem!),
            const SizedBox(height: 12),
            _buildResultRow(
              'Trust Score',
              '${(_trustScore * 100).toStringAsFixed(0)}%',
              color: _getTrustScoreColor(_trustScore),
            ),
            const SizedBox(height: 12),
            _buildTrustScoreBar(),
            const SizedBox(height: 8),
            Text(
              _getTrustScoreDescription(_trustScore),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildTrustScoreBar() {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: _trustScore,
        child: Container(
          decoration: BoxDecoration(
            color: _getTrustScoreColor(_trustScore),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Add any additional details...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a description';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    final canSubmit = _capturedImage != null && _currentLocation != null;
    
    return ElevatedButton(
      onPressed: canSubmit ? _submitReport : null,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        'Submit Report',
        style: AppTextStyles.buttonText,
      ),
    );
  }

  Color _getTrustScoreColor(double score) {
    if (score >= 0.7) return AppColors.successColor;
    if (score >= 0.4) return AppColors.warningColor;
    return AppColors.errorColor;
  }

  String _getTrustScoreDescription(double score) {
    if (score >= 0.8) {
      return 'High confidence match. Very low likelihood of fraud.';
    } else if (score >= 0.6) {
      return 'Good match. Low likelihood of fraud.';
    } else if (score >= 0.4) {
      return 'Moderate match. Manual review recommended.';
    } else {
      return 'Low confidence match. High likelihood of fraud.';
    }
  }
}
