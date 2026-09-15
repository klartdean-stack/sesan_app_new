import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final bool isShopLocation;
  const MapPickerScreen({super.key, this.initialLat, this.initialLng, this.isShopLocation = false});
  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  static const LatLng _phnomPenh = LatLng(11.5564, 104.9282);
  GoogleMapController? _mapController;
  late LatLng _selectedLocation;
  bool _locationPermissionGranted = false;
  bool _isLocating = false;
  bool _locationServiceDisabled = false;
  bool _locationPermissionBlocked = false;
  String? _locationError;
  bool get _hasInitialLocation => widget.initialLat != null && widget.initialLng != null;
  bool get _isEnglish => Localizations.localeOf(context).languageCode == 'en';

  @override
  void initState() {
    super.initState();
    _selectedLocation = _hasInitialLocation ? LatLng(widget.initialLat!, widget.initialLng!) : _phnomPenh;
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareLocation());
  }

  @override
  void dispose() { _mapController?.dispose(); super.dispose(); }

  Future<void> _prepareLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) setState(() { _locationServiceDisabled = true; _locationPermissionBlocked = false; _locationError = _isEnglish ? 'Location/GPS is off. Tap here to turn it on.' : 'Location/GPS ត្រូវបានបិទ។ ចុចទីនេះដើម្បីបើក។'; });
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (mounted) setState(() { _locationServiceDisabled = false; _locationPermissionBlocked = permission == LocationPermission.deniedForever; _locationError = permission == LocationPermission.deniedForever ? (_isEnglish ? 'Location permission is blocked. Tap here to open Settings.' : 'Location Permission ត្រូវបានបិទ។ ចុចទីនេះដើម្បីបើក Settings។') : (_isEnglish ? 'Location permission was not granted.' : 'មិនទាន់បានអនុញ្ញាត Location ទេ។'); });
      return;
    }
    if (mounted) setState(() { _locationPermissionGranted = true; _locationServiceDisabled = false; _locationPermissionBlocked = false; _locationError = null; });
    if (!_hasInitialLocation) await _moveToCurrentLocation();
  }

  Future<void> _moveToCurrentLocation() async {
    if (_isLocating) return;
    setState(() { _isLocating = true; _locationError = null; });
    try {
      final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
      final target = LatLng(position.latitude, position.longitude);
      _selectedLocation = target;
      await _mapController?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: 17)));
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _locationError = _isEnglish ? 'Could not get your current location.' : 'មិនអាចរកទីតាំងបច្ចុប្បន្នបានទេ។');
    } finally { if (mounted) setState(() => _isLocating = false); }
  }

  Future<void> _selectLocationFromTap(LatLng target) async { if (mounted) setState(() => _selectedLocation = target); await _mapController?.animateCamera(CameraUpdate.newLatLng(target)); }
  Future<void> _openRequiredLocationSetting() async { if (_locationServiceDisabled) { await Geolocator.openLocationSettings(); } else if (_locationPermissionBlocked) { await Geolocator.openAppSettings(); } else { await _prepareLocation(); return; } if (mounted) await _prepareLocation(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isShopLocation ? (_isEnglish ? 'Pin shop location' : 'កំណត់ទីតាំងហាង') : (_isEnglish ? 'Pin product location' : 'កំណត់ទីតាំងទំនិញ'), style: const TextStyle(fontFamily: 'Siemreap', fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green.shade700, foregroundColor: Colors.white,
        actions: [TextButton.icon(onPressed: () => Navigator.pop(context, _selectedLocation), icon: const Icon(Icons.check, color: Colors.white, size: 18), label: Text(_isEnglish ? 'Confirm' : 'យល់ព្រម', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Siemreap')))],
      ),
      body: Stack(children: [
        GoogleMap(initialCameraPosition: CameraPosition(target: _selectedLocation, zoom: _hasInitialLocation ? 17 : 14), onMapCreated: (c) => _mapController = c, onTap: _selectLocationFromTap, onCameraMove: (p) => _selectedLocation = p.target, onCameraIdle: () { if (mounted) setState(() {}); }, myLocationEnabled: _locationPermissionGranted, myLocationButtonEnabled: false, zoomControlsEnabled: false, mapToolbarEnabled: false),
        const IgnorePointer(child: Center(child: Padding(padding: EdgeInsets.only(bottom: 42), child: Icon(Icons.location_on, color: Colors.red, size: 52, shadows: [Shadow(color: Colors.black38, blurRadius: 8, offset: Offset(0,4))])))),
        Positioned(left: 14, right: 14, bottom: 18, child: SafeArea(top: false, child: Material(elevation: 6, borderRadius: BorderRadius.circular(16), child: Container(padding: const EdgeInsets.fromLTRB(14,10,8,10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Row(children: [const Icon(Icons.pin_drop_outlined, color: Colors.green), const SizedBox(width: 10), Expanded(child: Text('${_selectedLocation.latitude.toStringAsFixed(6)}, ${_selectedLocation.longitude.toStringAsFixed(6)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))), IconButton(onPressed: _isLocating ? null : (_locationPermissionGranted ? _moveToCurrentLocation : _prepareLocation), icon: _isLocating ? const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.my_location,color:Colors.green))]))))),
        if (_locationError != null) Positioned(top:12,left:12,right:12,child:Material(color:Colors.red.shade700,borderRadius:BorderRadius.circular(12),child:InkWell(onTap:_locationServiceDisabled||_locationPermissionBlocked?_openRequiredLocationSetting:null,borderRadius:BorderRadius.circular(12),child:Padding(padding:const EdgeInsets.all(12),child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.settings,color:Colors.white,size:18),const SizedBox(width:8),Flexible(child:Text(_locationError!,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontFamily:'Siemreap',fontSize:12,fontWeight:FontWeight.bold)))]))))),
      ]),
    );
  }
}
