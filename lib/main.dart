import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'services/database_helper.dart';

void main() {
  runApp(DictionaryApp());
}

class DictionaryApp extends StatelessWidget {
  const DictionaryApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dzongkha-English Dictionary',
      home: DictionaryHomePage(),
    );
  }
}

class DictionaryHomePage extends StatefulWidget {
  @override
  _DictionaryHomePageState createState() => _DictionaryHomePageState();
}

class _DictionaryHomePageState extends State<DictionaryHomePage> {
  Map<String, String> enDz = {};
  Map<String, String> dzEn = {};
  List<String> searchHistory = [];
  List<String> favorites = [];
  String searchQuery = '';
  String resultEnDz = '';
  String resultDzEn = '';
  DatabaseHelper databaseHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    loadData();
    loadFromDatabase();
  }

  Future<void> loadData() async {
    final String enDzString = await rootBundle.loadString('assets/en-dz.json');
    final String dzEnString = await rootBundle.loadString('assets/dz-en.json');

    setState(() {
      enDz = Map<String, String>.from(json.decode(enDzString));
      dzEn = Map<String, String>.from(json.decode(dzEnString));
    });
  }

  Future<void> loadFromDatabase() async {
    List<String> favs = await databaseHelper.getFavorites();
    List<String> history = await databaseHelper.getHistory();
    setState(() {
      favorites = favs;
      searchHistory = history;
    });
  }

  // Function to extract definition from markup text
  String extractDefinition(String markupText) {
    final defStart = markupText.indexOf('<def>') + 5;  // +5 to skip "<def>"
    final defEnd = markupText.indexOf('</def>');

    if (defStart == -1 || defEnd == -1) {
      return markupText;  // If <def> tags are not found, return the full text
    }

    return markupText.substring(defStart, defEnd);  // Return the definition between <def> and </def>
  }

  void searchWord() async {
    if (searchQuery.isEmpty) return;

    String normalizedQuery = searchQuery.trim();
    print("Searching for: $normalizedQuery");

    // Search for English -> Dzongkha in enDz
    String enDzTranslation = enDz[normalizedQuery] ?? '';

    // Search for Dzongkha -> English in dzEn
    String dzEnRawTranslation = dzEn[normalizedQuery] ?? '';

    // Parse Dzongkha -> English translation by extracting the <def> tag content
    String dzEnTranslation = dzEnRawTranslation.isNotEmpty
        ? extractDefinition(dzEnRawTranslation)
        : 'No translation found';

    print("English -> Dzongkha result: $enDzTranslation");
    print("Dzongkha -> English result: $dzEnTranslation");

    setState(() {
      resultEnDz = enDzTranslation.isNotEmpty ? enDzTranslation : 'No translation found';
      resultDzEn = dzEnTranslation;
    });

    // Save search history
    await databaseHelper.insertHistory(normalizedQuery);
    loadFromDatabase();
  }

  void toggleFavorite(String word) async {
    if (favorites.contains(word)) {
      await databaseHelper.deleteFavorite(word);
    } else {
      await databaseHelper.insertFavorite(word);
    }
    loadFromDatabase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dzongkha-English Dictionary'),
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HistoryPage(searchHistory)),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.favorite),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FavoritesPage(favorites)),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
              decoration: InputDecoration(
                labelText: 'Search English or Dzongkha',
                border: OutlineInputBorder(),
              ),
            ),
            ElevatedButton(
              onPressed: searchWord,
              child: Text('Search'),
            ),
            SizedBox(height: 20),

            // Display English -> Dzongkha result
            if (resultEnDz.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('English -> Dzongkha:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(resultEnDz, style: TextStyle(fontSize: 18)),
                ],
              ),

            SizedBox(height: 10),

            // Display Dzongkha -> English result
            if (resultDzEn.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dzongkha -> English:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(resultDzEn, style: TextStyle(fontSize: 18)),
                ],
              ),

            if (searchQuery.isNotEmpty)
              IconButton(
                icon: favorites.contains(searchQuery)
                    ? Icon(Icons.favorite, color: Colors.red)
                    : Icon(Icons.favorite_border),
                onPressed: () => toggleFavorite(searchQuery),
              ),
          ],
        ),
      ),
    );
  }
}

class HistoryPage extends StatelessWidget {
  final List<String> searchHistory;

  HistoryPage(this.searchHistory);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Search History')),
      body: ListView.builder(
        itemCount: searchHistory.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(searchHistory[index]),
          );
        },
      ),
    );
  }
}

class FavoritesPage extends StatelessWidget {
  final List<String> favorites;

  FavoritesPage(this.favorites);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Favorites')),
      body: ListView.builder(
        itemCount: favorites.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(favorites[index]),
          );
        },
      ),
    );
  }
}
