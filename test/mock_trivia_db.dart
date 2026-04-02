import 'package:cloud_firestore/cloud_firestore.dart';

void populateMockTriviaDB(FirebaseFirestore firestore) async {
  final batch = firestore.batch();

  final categories = {
    'Genel Kültür': [],
    'Tarih': [],
    'Coğrafya': [],
    'Bilim': [],
    'Spor': [],
  };

  // Create 100 questions per category
  for (final cat in categories.keys) {
    for (int i = 1; i <= 100; i++) {
      final docId = 'q_${cat.replaceAll(" ", "_")}_$i';
      final ref = firestore
          .collection('Games')
          .doc('Trivia')
          .collection('Questions')
          .doc(cat)
          .collection('sorular')
          .doc(docId);

      String diff = 'kolay';
      if (i > 33 && i <= 66) {
        diff = 'orta';
      } else if (i > 66) diff = 'zor';

      batch.set(ref, {
        'id': docId,
        'question': '$cat kategorisinde $diff seviye $i. soru nedir?',
        'options': ['Seçenek A $i', 'Seçenek B $i', 'Seçenek C $i', 'Seçenek D $i'],
        'correctAnswer': 'Seçenek A $i',
        'difficulty': diff,
      });
    }
  }

  await batch.commit();
}
