import 'package:flutter/material.dart';
import '../location_data.dart';
import '../vireak_buntham_data.dart';
import 'localized_text.dart';

class LocationPickerSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onLocationSelected;

  const LocationPickerSheet({super.key, required this.onLocationSelected});

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final TextEditingController _addressController = TextEditingController();

  String? selectedProvince;
  String? selectedDistrict;
  String? selectedVireakBranch;
  bool isVireakBuntham = false;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) {
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.location_on, color: Colors.green[700], size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(appText(context, km: 'ទំលាក់ទីតាំងទទួល', en: 'Delivery location'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                            Text(appText(context, km: 'បំពេញព័ត៌មានដឹកជញ្ជូន', en: 'Enter delivery information'), style: const TextStyle(fontSize: 13, color: Colors.grey)),
                          ],
                        ),
                      ),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _buildDropdown(
                        label: appText(context, km: 'ជ្រើសរើសខេត្ត/ក្រុង', en: 'Select province/city'),
                        icon: Icons.map_outlined,
                        value: selectedProvince,
                        items: cambodiaProvinceData.keys.toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedProvince = val;
                            selectedDistrict = null;
                            selectedVireakBranch = null;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: SwitchListTile(
                          title: Text(appText(context, km: 'ផ្ញើតាមវិរៈប៊ុនថាំ', en: 'Send via Vireak Buntham'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red)),
                          value: isVireakBuntham,
                          onChanged: (val) {
                            setState(() {
                              isVireakBuntham = val;
                              selectedDistrict = null;
                              selectedVireakBranch = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (selectedProvince != null)
                        isVireakBuntham
                            ? _buildDropdown(
                                label: appText(context, km: 'ជ្រើសរើសសាខាវិរៈ', en: 'Select Vireak branch'),
                                icon: Icons.store_outlined,
                                value: selectedVireakBranch,
                                iconColor: Colors.red,
                                items: VETData.branches[selectedProvince] ?? [],
                                onChanged: (val) => setState(() => selectedVireakBranch = val),
                              )
                            : _buildDropdown(
                                label: appText(context, km: 'ជ្រើសរើសស្រុក/ខណ្ឌ', en: 'Select district'),
                                icon: Icons.location_city_outlined,
                                value: selectedDistrict,
                                items: cambodiaProvinceData[selectedProvince!] ?? [],
                                onChanged: (val) => setState(() => selectedDistrict = val),
                              ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _addressController,
                        maxLines: 3,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(color: Color(0xFF1A1A1A)),
                        decoration: InputDecoration(
                          labelText: appText(context, km: 'លេខទូរស័ព្ទ/អាសយដ្ឋានលម្អិត', en: 'Phone number / detailed address'),
                          labelStyle: const TextStyle(color: Color(0xFF555555)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _canSubmit() ? _submitLocation : null,
                          icon: const Icon(Icons.send),
                          label: Text(appText(context, km: 'ផ្ញើទីតាំង', en: 'Send location')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    Color? iconColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        dropdownColor: Colors.white,
        style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A1A)),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF555555)),
          prefixIcon: Icon(icon, color: iconColor ?? Colors.grey.shade600),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        items: items
            .map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(
                    s,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A1A)),
                  ),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  bool _canSubmit() {
    if (selectedProvince == null) return false;
    if (isVireakBuntham) {
      return selectedVireakBranch != null && _addressController.text.trim().isNotEmpty;
    }
    return selectedDistrict != null && _addressController.text.trim().isNotEmpty;
  }

  void _submitLocation() {
    final locationData = {
      'province': selectedProvince!,
      'district': isVireakBuntham ? null : selectedDistrict,
      'vireakBranch': isVireakBuntham ? selectedVireakBranch : null,
      'address': _addressController.text.trim(),
      'isVireakBuntham': isVireakBuntham,
    };
    widget.onLocationSelected(locationData);
    Navigator.pop(context);
  }
}
