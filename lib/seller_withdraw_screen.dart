import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'edit_profile_screen.dart';
import 'localized_text.dart';

class SellerWithdrawScreen extends StatefulWidget {
  const SellerWithdrawScreen({super.key});
  @override
  State<SellerWithdrawScreen> createState() => _SellerWithdrawScreenState();
}

class _SellerWithdrawScreenState extends State<SellerWithdrawScreen> {
  final TextEditingController _amountController = TextEditingController();
  final currencyFormat = NumberFormat('#,###');
  String? userId;
  double _canWithdraw = 0;

  @override
  void initState() { super.initState(); _loadUserId(); }
  @override
  void dispose() { _amountController.dispose(); super.dispose(); }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => userId = prefs.getString('user_uid'));
  }

  void _showWithdrawDialog() {
    final pinController = TextEditingController();
    bool isSubmitting = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          if (userData['bank_account_number'] == null || userData['password'] == null) {
            return AlertDialog(
              title: Text(appText(context, km: 'ព័ត៌មានមិនទាន់គ្រប់គ្រាន់', en: 'Information incomplete'), style: const TextStyle(fontFamily: 'KHMEROS')),
              content: Text(appText(context, km: 'សូមបំពេញព័ត៌មានធនាគារ និងលេខសម្ងាត់ ៦ ខ្ទង់ ជាមុនសិន ទើបអាចដកប្រាក់បាន។', en: 'Please complete your bank information and 6-digit PIN before withdrawing.')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(appText(context, km: 'បោះបង់', en: 'Cancel'))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())); },
                  child: Text(appText(context, km: 'ទៅបំពេញព័ត៌មាន', en: 'Complete information'), style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
          return StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(appText(context, km: 'បញ្ជាក់ការដកប្រាក់', en: 'Confirm withdrawal'), style: const TextStyle(fontFamily: 'Siemreap', fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)), child: ListTile(leading: const Icon(Icons.account_balance, color: Colors.green), title: Text(userData['bank_name'] ?? 'ABA'), subtitle: Text(userData['bank_account_number'] ?? ''))),
              const SizedBox(height: 20),
              Text(appText(context, km: 'បញ្ចូលលេខសម្ងាត់ ៦ ខ្ទង់', en: 'Enter your 6-digit PIN')),
              const SizedBox(height: 10),
              TextField(controller: pinController, decoration: const InputDecoration(hintText: '* * * * * *', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(vertical: 10)), obscureText: true, textAlign: TextAlign.center, keyboardType: TextInputType.number, maxLength: 6),
            ])),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(appText(context, km: 'បោះបង់', en: 'Cancel'))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: isSubmitting ? null : () async {
                  final inputPin = pinController.text.trim();
                  final amount = double.tryParse(_amountController.text.trim()) ?? 0;
                  if (!RegExp(r'^\d{6}$').hasMatch(inputPin)) { _showSnackBar(appText(context, km: '⚠️ លេខសម្ងាត់ត្រូវមាន ៦ ខ្ទង់', en: '⚠️ PIN must contain 6 digits'), isError: true); return; }
                  setDialogState(() => isSubmitting = true);
                  try {
                    final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1').httpsCallable('secureWithdraw');
                    await callable.call({'amount': amount, 'pin': inputPin});
                    if (!mounted) return;
                    Navigator.pop(context); _amountController.clear();
                    _showSnackBar(appText(context, km: '✅ សំណើដកប្រាក់ត្រូវបានបញ្ជូន!', en: '✅ Withdrawal request submitted!'));
                  } on FirebaseFunctionsException catch (e) {
                    if (!mounted) return; setDialogState(() => isSubmitting = false);
                    _showSnackBar(e.message ?? appText(context, km: '❌ មិនអាចបង្កើតសំណើដកប្រាក់បានទេ', en: '❌ Unable to submit withdrawal request'), isError: true);
                  } catch (e) {
                    if (!mounted) return; setDialogState(() => isSubmitting = false);
                    _showSnackBar(appText(context, km: '❌ កំហុសបច្ចេកទេស៖ $e', en: '❌ Technical error: $e'), isError: true);
                  }
                },
                child: isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(appText(context, km: 'យល់ព្រម', en: 'Confirm')),
              ),
            ],
          ));
        },
      ),
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontFamily: 'Siemreap')), backgroundColor: isError ? Colors.red : Colors.green));
  }

  String _statusText(String status) {
    switch (status.toLowerCase()) { case 'success': case 'approved': case 'completed': return appText(context, km: 'ជោគជ័យ', en: 'Successful'); case 'rejected': case 'cancelled': return appText(context, km: 'បដិសេធ', en: 'Rejected'); default: return appText(context, km: 'កំពុងរង់ចាំ', en: 'Pending'); }
  }
  Color _statusColor(String status) { switch (status.toLowerCase()) { case 'success': case 'approved': case 'completed': return Colors.green; case 'rejected': case 'cancelled': return Colors.red; default: return Colors.orange; } }
  IconData _statusIcon(String status) { switch (status.toLowerCase()) { case 'success': case 'approved': case 'completed': return Icons.check_circle; case 'rejected': case 'cancelled': return Icons.cancel; default: return Icons.schedule; } }

  Widget _buildWithdrawalHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('withdraw_requests').where('seller_id', isEqualTo: userId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Colors.green)));
        if (snapshot.hasError) return Text(appText(context, km: 'មិនអាចទាញប្រវត្តិដកប្រាក់បានទេ', en: 'Unable to load withdrawal history'), style: const TextStyle(color: Colors.red));
        final requests = snapshot.data?.docs.toList() ?? [];
        requests.sort((a,b) { final ad=(a.data() as Map<String,dynamic>)['created_at'] as Timestamp?; final bd=(b.data() as Map<String,dynamic>)['created_at'] as Timestamp?; return (bd?.millisecondsSinceEpoch??0).compareTo(ad?.millisecondsSinceEpoch??0); });
        if (requests.isEmpty) return Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16)), child: Column(children: [Icon(Icons.history_rounded, size: 38, color: Colors.grey.shade400), const SizedBox(height:8), Text(appText(context, km:'មិនទាន់មានប្រវត្តិស្នើដកប្រាក់', en:'No withdrawal requests yet'))]));
        return Column(children: requests.map((doc) {
          final data=doc.data() as Map<String,dynamic>; final amount=(data['amount'] as num?)?.toDouble()??0; final status=(data['status']??'pending').toString(); final color=_statusColor(status); final created=data['created_at'] as Timestamp?; final date=created==null?appText(context,km:'កំពុងដំណើរការ...',en:'Processing...'):DateFormat('dd/MM/yyyy • HH:mm').format(created.toDate());
          return Card(elevation:0, margin:const EdgeInsets.only(bottom:12), shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16),side:BorderSide(color:color.withOpacity(.22))), child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[Row(children:[Container(width:44,height:44,decoration:BoxDecoration(color:color.withOpacity(.12),borderRadius:BorderRadius.circular(12)),child:Icon(_statusIcon(status),color:color)),const SizedBox(width:12),Expanded(child:Text('${currencyFormat.format(amount)} ៛',style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold))),Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:color.withOpacity(.12),borderRadius:BorderRadius.circular(20)),child:Text(_statusText(status),style:TextStyle(color:color,fontSize:11,fontWeight:FontWeight.bold))) ]),const SizedBox(height:12),Row(children:[const Icon(Icons.calendar_today_outlined,size:15),const SizedBox(width:7),Expanded(child:Text(date,style:const TextStyle(fontSize:12))),if((data['bank_name']??'').toString().isNotEmpty) Text(data['bank_name'].toString(),style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600))])])));
        }).toList());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (userId == null) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.green)));
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(appText(context, km:'ដកប្រាក់ចំណូល', en:'Withdraw earnings'), style:const TextStyle(fontFamily:'Siemreap')),centerTitle:true,elevation:0,backgroundColor:Colors.white,foregroundColor:Colors.black),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
        builder:(context,snapshot){
          if(snapshot.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
          if(!snapshot.hasData||!snapshot.data!.exists)return Center(child:Text(appText(context,km:'រកមិនឃើញគណនី',en:'Account not found')));
          final data=snapshot.data!.data() as Map<String,dynamic>? ?? {}; _canWithdraw=(data['available_balance']??0).toDouble();
          return SingleChildScrollView(padding:const EdgeInsets.all(25),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Container(width:double.infinity,padding:const EdgeInsets.all(30),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Colors.green,Color(0xFF1B5E20)]),borderRadius:BorderRadius.circular(25)),child:Column(children:[Text(appText(context,km:'សមតុល្យដែលអាចដកបាន',en:'Available balance'),style:const TextStyle(color:Colors.white70)),const SizedBox(height:10),Text('${currencyFormat.format(_canWithdraw)} ៛',style:const TextStyle(color:Colors.white,fontSize:32,fontWeight:FontWeight.bold))])),
            const SizedBox(height:40),Text(appText(context,km:'ចំនួនទឹកប្រាក់ដែលចង់ដក',en:'Withdrawal amount'),style:const TextStyle(fontWeight:FontWeight.bold)),const SizedBox(height:10),
            TextField(controller:_amountController,keyboardType:TextInputType.number,decoration:InputDecoration(hintText:'0 ៛',prefixIcon:const Icon(Icons.account_balance_wallet,color:Colors.green),border:OutlineInputBorder(borderRadius:BorderRadius.circular(15)))),
            const SizedBox(height:12),Wrap(spacing:8,children:[50000,100000,200000,500000].map((amount)=>OutlinedButton(onPressed:()=>_amountController.text=amount.toString(),child:Text('${currencyFormat.format(amount)} ៛'))).toList()),
            const SizedBox(height:50),SizedBox(width:double.infinity,height:60,child:ElevatedButton(style:ElevatedButton.styleFrom(backgroundColor:Colors.green),onPressed:(){final amount=double.tryParse(_amountController.text)??0;if(amount<5000){_showSnackBar(appText(context,km:'⚠️ ចំនួនដកត្រូវតែចាប់ពី ៥,០០០៛ ឡើងទៅ',en:'⚠️ Minimum withdrawal is 5,000៛'),isError:true);return;}if(amount>_canWithdraw){_showSnackBar(appText(context,km:'⚠️ លុយក្នុងកាបូបមិនគ្រប់គ្រាន់ទេ!',en:'⚠️ Insufficient wallet balance!'),isError:true);return;}_showWithdrawDialog();},child:Text(appText(context,km:'បញ្ជាក់ការដកប្រាក់',en:'Confirm withdrawal'),style:const TextStyle(fontSize:18,color:Colors.white)))),
            const SizedBox(height:36),Text(appText(context,km:'ប្រវត្តិស្នើដកប្រាក់',en:'Withdrawal request history'),style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),const SizedBox(height:14),_buildWithdrawalHistory(),
          ]));
        },
      ),
    );
  }
}
