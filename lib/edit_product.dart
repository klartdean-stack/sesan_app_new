import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:my_app/map_picker_screen.dart';
import 'package:my_app/product_list.dart';
import 'package:my_app/location_picker.dart';
import 'localized_text.dart';

class EditProductScreen extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;
  final bool isWanted;
  final String? currentUserId;

  const EditProductScreen({super.key, required this.productId, required this.productData, required this.isWanted, this.currentUserId});
  @override State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController, _priceController, _stockQuantityController, _stockUnitController, _descController, _phoneController, _locationController;
  final ImagePicker _picker = ImagePicker();
  List<File> _imageFiles = [];
  List<String> _existingImageUrls = [];
  bool _isLoading = false, _isOwner = false;
  double? selectedLat, selectedLng;

  @override void initState() {
    super.initState(); CambodiaLocationService.load(); _checkOwnership();
    final d=widget.productData; var price=d['price']?.toString()??'';
    try { if(price.isNotEmpty) price=NumberFormat('#,###').format(int.parse(price.replaceAll(',',''))); } catch (_) {}
    _priceController=TextEditingController(text:price);
    _stockQuantityController=TextEditingController(text:d['stock_quantity']?.toString()??'');
    _stockUnitController=TextEditingController(text:d['stock_unit']?.toString()??'');
    _nameController=TextEditingController(text:d['product_name']?.toString()??'');
    _descController=TextEditingController(text:d['description']?.toString()??'');
    _phoneController=TextEditingController(text:d['phone1']?.toString()??'');
    _locationController=TextEditingController(text:d['location']?.toString()??'');
    selectedLat=d['lat'] is num?(d['lat'] as num).toDouble():null; selectedLng=d['lng'] is num?(d['lng'] as num).toDouble():null;
    if(d['image_urls']!=null) _existingImageUrls=List<String>.from(d['image_urls']); else if(d['image_url']!=null) _existingImageUrls=[d['image_url'].toString()];
  }
  @override void dispose(){for(final c in [_nameController,_priceController,_stockQuantityController,_stockUnitController,_descController,_phoneController,_locationController]){c.dispose();}super.dispose();}
  Future<void> _checkOwnership() async { final id=widget.currentUserId??await UserService.getUserId(); final owner=widget.isWanted?widget.productData['userId']:widget.productData['seller_id']; if(mounted)setState(()=>_isOwner=id!=null&&owner!=null&&id==owner); }
  Future<void> _pickImages() async { final xs=await _picker.pickMultiImage(imageQuality:50); if(xs.isNotEmpty&&mounted)setState(()=>_imageFiles.addAll(xs.map((x)=>File(x.path)))); }
  Future<void> _fillLocationFromMap(LatLng p) async { try{final ps=await placemarkFromCoordinates(p.latitude,p.longitude);if(!mounted)return;final parts=<String>[];void add(String? v){final x=v?.trim()??'';if(x.isNotEmpty&&!parts.any((e)=>e.toLowerCase()==x.toLowerCase()))parts.add(x);}if(ps.isNotEmpty){final x=ps.first;add(x.administrativeArea);add(x.subAdministrativeArea);add(x.locality);add(x.subLocality);}setState(()=>_locationController.text=parts.isNotEmpty?parts.join(', '):'${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}');}catch(e){if(mounted)setState(()=>_locationController.text='${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}');}}
  Future<void> _updateProduct() async {
    if(!_isOwner){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(appText(context,km:'🚫 អ្នកមិនមានសិទ្ធិកែប្រែទំនិញនេះទេ',en:'🚫 You do not have permission to edit this product'))));return;}
    if(!_formKey.currentState!.validate())return; setState(()=>_isLoading=true);
    try{final urls=List<String>.from(_existingImageUrls);for(final f in _imageFiles){final r=FirebaseStorage.instance.ref('products/images/${DateTime.now().microsecondsSinceEpoch}.jpg');await r.putFile(f);urls.add(await r.getDownloadURL());}
      final stock=_stockQuantityController.text.trim(); final n=int.tryParse(stock);
      await FirebaseFirestore.instance.collection('products').doc(widget.productId).update({'product_name':_nameController.text.trim(),'price':_priceController.text.trim(),'description':_descController.text.trim(),'track_stock':stock.isNotEmpty,if(stock.isNotEmpty)'stock_quantity':n,if(stock.isNotEmpty)'stock_unit':_stockUnitController.text.trim(),if(stock.isNotEmpty)'is_available':(n??0)>0,'phone1':_phoneController.text.trim(),'location':_locationController.text.trim(),'lat':selectedLat,'lng':selectedLng,'image_urls':urls,'updatedAt':FieldValue.serverTimestamp(),'seller_id':widget.productData['seller_id']});
      if(mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(appText(context,km:'✅ កែប្រែបានសម្រេច!',en:'✅ Product updated successfully!')),backgroundColor:Colors.green));Navigator.pop(context);}
    }catch(e){debugPrint('Update Error: $e');}finally{if(mounted)setState(()=>_isLoading=false);}
  }
  @override Widget build(BuildContext context){if(!_isOwner&&!_isLoading)return Scaffold(body:Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.block,size:80,color:Colors.red),const SizedBox(height:20),Text(appText(context,km:'🚫 អ្នកមិនមានសិទ្ធិកែប្រែទំនិញនេះទេ',en:'🚫 You do not have permission to edit this product'),textAlign:TextAlign.center),ElevatedButton(onPressed:()=>Navigator.pop(context),child:Text(appText(context,km:'ត្រឡប់ក្រោយ',en:'Go back')))])));
    return Scaffold(appBar:AppBar(title:Text(appText(context,km:'កែប្រែផលិតផល',en:'Edit product')),backgroundColor:Colors.green[700],foregroundColor:Colors.white),body:_isLoading?const Center(child:CircularProgressIndicator()):SingleChildScrollView(padding:const EdgeInsets.all(20),child:Form(key:_formKey,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(appText(context,km:'រូបភាពផលិតផល',en:'Product images'),style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16)),const SizedBox(height:10),Wrap(spacing:10,runSpacing:10,children:[GestureDetector(onTap:_pickImages,child:Container(width:90,height:90,decoration:BoxDecoration(color:Colors.grey[200],borderRadius:BorderRadius.circular(10)),child:const Icon(Icons.add_a_photo))),..._existingImageUrls.map((u)=>_imageTile(Image.network(u,width:90,height:90,fit:BoxFit.cover),()=>setState(()=>_existingImageUrls.remove(u)))),..._imageFiles.map((f)=>_imageTile(Image.file(f,width:90,height:90,fit:BoxFit.cover),()=>setState(()=>_imageFiles.remove(f))))]),const SizedBox(height:25),_input(_nameController,appText(context,km:'ឈ្មោះផលិតផល',en:'Product name'),Icons.shopping_bag),_input(_priceController,appText(context,km:'តម្លៃ (៛)',en:'Price (៛)'),Icons.account_balance_wallet,number:true),Row(children:[Expanded(child:_input(_stockQuantityController,appText(context,km:'ចំនួនស្តុក',en:'Stock quantity'),Icons.inventory_2_outlined,number:true,required:false)),const SizedBox(width:10),Expanded(child:_input(_stockUnitController,appText(context,km:'ឯកតា (ដើម, គីឡូ...)',en:'Unit (item, kg...)'),Icons.straighten,required:false))]),_input(_phoneController,appText(context,km:'លេខទូរស័ព្ទ',en:'Phone number'),Icons.phone,number:true),_input(_descController,appText(context,km:'ការពិពណ៌នា',en:'Description'),Icons.description,lines:3),Row(children:[Expanded(flex:3,child:InkWell(onTap:()=>showLocationPicker(context,onSelected:(v)=>setState(()=>_locationController.text=v.toString())),child:Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(border:Border.all(color:Colors.grey.shade300),borderRadius:BorderRadius.circular(12)),child:Text(_locationController.text.isEmpty?appText(context,km:'ជ្រើសរើសទីតាំង *',en:'Select location *'):_locationController.text,maxLines:1,overflow:TextOverflow.ellipsis)))),const SizedBox(width:10),Expanded(child:ElevatedButton(onPressed:()async{final r=await Navigator.push<LatLng>(context,MaterialPageRoute(builder:(_)=>MapPickerScreen(initialLat:selectedLat,initialLng:selectedLng)));if(r!=null&&mounted){setState((){selectedLat=r.latitude;selectedLng=r.longitude;});await _fillLocationFromMap(r);}},child:Icon(selectedLat!=null?Icons.location_on:Icons.map_outlined)))]),const SizedBox(height:30),SizedBox(width:double.infinity,height:50,child:ElevatedButton(onPressed:_updateProduct,child:Text(appText(context,km:'រក្សាទុកការកែប្រែ',en:'Save changes'))))]))));}
  Widget _imageTile(Widget image,VoidCallback remove)=>Stack(children:[ClipRRect(borderRadius:BorderRadius.circular(10),child:image),Positioned(right:0,top:0,child:GestureDetector(onTap:remove,child:const CircleAvatar(radius:12,backgroundColor:Colors.red,child:Icon(Icons.close,size:16,color:Colors.white))))]);
  Widget _input(TextEditingController c,String label,IconData icon,{bool number=false,int lines=1,bool required=true})=>Padding(padding:const EdgeInsets.only(bottom:15),child:TextFormField(controller:c,maxLines:lines,keyboardType:number?TextInputType.number:TextInputType.text,inputFormatters:number&&label.contains('Price')||number&&label.contains('តម្លៃ')?[FilteringTextInputFormatter.digitsOnly,ThousandsSeparatorInputFormatter()]:null,decoration:InputDecoration(labelText:label,prefixIcon:Icon(icon),border:OutlineInputBorder(borderRadius:BorderRadius.circular(12))),validator:(v){if(required&&(v==null||v.trim().isEmpty))return appText(context,km:'សូមបំពេញ $label',en:'Please enter $label');if(number&&v!=null&&v.trim().isNotEmpty&&int.tryParse(v.replaceAll(',',''))==null)return appText(context,km:'សូមបញ្ចូលលេខត្រឹមត្រូវ',en:'Please enter a valid number');return null;}));
}
