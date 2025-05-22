
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

class FirestoreContentWidget2 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    CollectionReference script = FirebaseFirestore.instance.collection('script');
    FirebaseStorage storage = FirebaseStorage.instance;

    return StreamBuilder<DocumentSnapshot>(
      stream: script.doc('pagehome2').snapshots(),
      builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
        if (snapshot.hasError) {
          return const Text("Quelque chose s'est mal passé");
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        Map<String, dynamic> data = snapshot.data!.data() as Map<String, dynamic>;
        return buildContent(data, storage);  // Ajout de cette ligne pour retourner un widget
      },
    );
  }

  Widget buildContent(Map<String, dynamic> data, FirebaseStorage storage) {
    return FutureBuilder(
      future: storage.ref(data['imagePath']).getDownloadURL(),
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        if (snapshot.hasError) {
          return const Text('Erreur lors du chargement de l\'image');
        }

        return Padding(
            padding: const EdgeInsets.only(top: 0.0).add(EdgeInsets.all(8.0)),
            child: SingleChildScrollView(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, // Centrer verticalement
                crossAxisAlignment: CrossAxisAlignment.center, // Centrer horizontalement
                children: [
                  Center(child: Text(data['title'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue))),
                  const SizedBox(height: 10),
                  Center(child: Text(data['description'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87))),
                  const SizedBox(height: 10),



                  Html(
                    data: data['content'],
                    style: {
                      "body": Style(fontSize: FontSize(14.0)),
                      "h1": Style(fontSize: FontSize(24.0), color: Colors.black87),
                      "h2": Style(fontSize: FontSize(16.0), color: Colors.black87),
                      "strong": Style(fontSize: FontSize(16.0), color: Colors.teal.shade300),
                      "br": Style(backgroundColor: Color(0xFF97EABF)),
                    },
                  ),
                ],
              ),
            )));

      },
    );
  }
}


