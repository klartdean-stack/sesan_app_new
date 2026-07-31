import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:my_app/admin_product_management.dart';
import 'package:my_app/use_detail_screen.dart';


class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});


  @override
  _AdminManagementScreenState createState() => _AdminManagementScreenState();
}


class _AdminManagementScreenState extends State<AdminManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String searchQuery = "";
  TextEditingController searchController = TextEditingController();


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F121F),
      appBar: AppBar(
        title: const Text(
          "គ្រប់គ្រងទិន្នន័យ",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF161B2E),
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blueAccent,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.shopping_bag), text: "ទំនិញ"),
            Tab(icon: Icon(Icons.people), text: "គណនី"),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSearchBox(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList(collection: "products", searchField: "product_name"),
                _buildList(collection: "users", searchField: "name"),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextField(
        controller: searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "ស្វែងរក...",
          hintStyle: const TextStyle(color: Colors.white24),
          prefixIcon: const Icon(Icons.search, color: Colors.white54),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear, color: Colors.white54),
            onPressed: () {
              searchController.clear();
              setState(() {
                searchQuery = "";
              });
            },
          )
              : null,
        ),
        onChanged: (value) => setState(() {
          searchQuery = value.trim();
        }),
      ),
    );
  }


  Widget _buildList({required String collection, required String searchField}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collection).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());


        // 🎯 មុខងារ Search គ្រប់ Key ទាំងអស់ដែលមានក្នុង Document
        var docs = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;


          // បំប្លែងទិន្នន័យទាំងអស់ក្នុង Document ឱ្យទៅជា String រួចឆែកមើល searchQuery
          // ធ្វើបែបនេះ មេវាយលេខ ID ក៏ឃើញ វាយលេខទូរសព្ទក៏ឃើញ វាយឈ្មោះក៏ឃើញ
          String allDataContent = data.values.join(" ").toLowerCase();
          return allDataContent.contains(searchQuery.toLowerCase());
        }).toList();


        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            String docId = docs[index].id;


            return Card(
              color: Colors.white.withOpacity(0.03),
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              // ... កូដពីលើរបស់មេ ...
              child: ListTile(
                // 🎯 ដាក់បន្ថែមពីលើ leading:
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => collection == "products"
                          ? ProductDetailScreen(productData: data)
                          : UserDetailScreen(userData: data),
                    ),
                  );
                },
                leading: _buildLeading(collection, data),
                title: Text(
                  data[searchField] ?? "No Name",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: _buildDynamicSubtitle(collection, data),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.delete_forever,
                    color: Colors.redAccent,
                  ),
                  onPressed: () => _confirmDelete(
                    context,
                    collection,
                    docId,
                    data[searchField] ?? "ទិន្នន័យ",
                    data,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }


  // 🎯 Widget បង្ហាញ Subtitle តាមប្រភេទ Collection
  Widget _buildDynamicSubtitle(String collection, Map<String, dynamic> data) {
    if (collection == "users") {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Sesan ID: ${data['sesan_id'] ?? '---'}",
            style: TextStyle(color: Colors.blueAccent, fontSize: 12),
          ),
          Text(
            "លេខទូរសព្ទ: ${data['phone'] ?? '---'}",
            style: TextStyle(color: Colors.greenAccent, fontSize: 12),
          ),
          Text(
            "Password: ${data['password'] ?? '**'}",
            style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
          ),
          Text(
            "សមតុល្យ: ${data['wallet_balance'] ?? 0}៛",
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      );
    } else {
      return Text(
        "តម្លៃ: ${data['price'] ?? 0}៛ | អ្នកលក់: ${data['seller_name'] ?? '---'}",
        style: const TextStyle(color: Colors.white60, fontSize: 12),
      );
    }
  }


  // 🎯 មុខងារថ្មី៖ បង្ហាញព័ត៌មានទាំងអស់ក្នុង Dialog (សម្រាប់ Admin ងាយស្រួលមើលគ្រប់ Key)
  void _showFullDetails(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B2E),
        title: const Text(
          "ព័ត៌មានលម្អិត",
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: data.entries
                .map(
                  (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  "${e.key}: ${e.value}",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ),
            )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("បិទ"),
          ),
        ],
      ),
    );
  }


  Widget _buildLeading(String collection, Map<String, dynamic> data) {
    if (collection == "products") {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          (data['image_urls'] != null && data['image_urls'].isNotEmpty)
              ? data['image_urls'][0]
              : "",
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.white10,
            child: const Icon(Icons.image, color: Colors.white24),
          ),
        ),
      );
    }
    // សម្រាប់ User: ទាញពី field photoUrl តាមរូបភាព Firebase
    return CircleAvatar(
      backgroundColor: Colors.indigo,
      backgroundImage: (data['photoUrl'] != null && data['photoUrl'] != "")
          ? NetworkImage(data['photoUrl'])
          : null,
      child: (data['photoUrl'] == null || data['photoUrl'] == "")
          ? const Icon(Icons.person, color: Colors.white)
          : null,
    );
  }


  Widget _buildSubtitle(
      String collection,
      Map<String, dynamic> data,
      String date,
      ) {
    if (collection == "products") {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "តម្លៃ: ${data['price'] ?? 0}៛",
            style: const TextStyle(color: Colors.orangeAccent, fontSize: 13),
          ),
          Text(
            "អ្នកលក់: ${data['seller_name'] ?? 'មិនស្គាល់'}",
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          if (date.isNotEmpty)
            Text(
              "កាលបរិច្ឆេទ: $date",
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
        ],
      );
    }
    // សម្រាប់ User បង្ហាញលេខទូរសព្ទ តួនាទី និងអាសយដ្ឋាន
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "លេខ: ${data['phone'] ?? 'គ្មាន'}",
          style: const TextStyle(color: Colors.greenAccent, fontSize: 13),
        ),
        Text(
          "តួនាទី: ${data['role'] ?? 'User'} | ទីតាំង: ${data['address'] ?? 'មិនមាន'}",
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    );
  }


  void _confirmDelete(
      BuildContext context,
      String collection,
      String docId,
      String name,
      Map<String, dynamic> data,
      ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "បញ្ជាក់ការលុប",
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "តើអ្នកប្រាកដថាចង់លុប '$name' មែនទេ?",
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 10),
            if (collection == "users")
              Text(
                "លេខទូរសព្ទ: ${data['phone1']}",
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            const Text(
              "\nសកម្មភាពនេះមិនអាចត្រឡប់ក្រោយបានឡើយ!",
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("បោះបង់"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection(collection)
                  .doc(docId)
                  .delete();
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("លុបបានជោគជ័យ")));
            },
            child: const Text("លុបចោល", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}



