import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

void main() {
  runApp(const AnimeWatchApp());
}

class AnimeWatchApp extends StatelessWidget {
  const AnimeWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AnimeWatch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF1B1B2F),
      ),
      home: const MainNavigation(),
    );
  }
}

// ==================== Thai Mapping ====================
Map<int, Map<String, String>> animeThaiMapping = {
  5114: {
    'title': 'โจโจ้ ล่าข้ามศตวรรษ',
    'synopsis': 'เรื่องราวของโจโจ้และการต่อสู้กับศัตรูเหนือธรรมชาติ',
  },
  9253: {
    'title': 'วันพีซ',
    'synopsis': 'การผจญภัยของลูฟี่และโจรสลัดหมวกฟางเพื่อค้นหาสมบัติลึกลับ',
  },
  1535: {
    'title': 'นารูโตะ',
    'synopsis': 'เรื่องราวของนินจาหนุ่มนารูโตะผู้ใฝ่ฝันจะเป็นโฮคาเงะ',
  },
};

// ==================== Navigation ====================
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final _pages = [
    const HomeScreen(),
    const SearchScreen(),
    const FavoritesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: Colors.deepPurpleAccent,
        unselectedItemColor: Colors.white70,
        backgroundColor: const Color(0xFF1B1B2F),
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "หน้าหลัก"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "ค้นหา"),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: "รายการโปรด",
          ),
        ],
      ),
    );
  }
}

// ==================== API Functions ====================
Future<List<dynamic>> getNowAiring() async {
  final url = Uri.parse('https://api.jikan.moe/v4/seasons/now');
  final res = await http.get(url);
  if (res.statusCode == 200) return jsonDecode(res.body)['data'];
  throw Exception('โหลดข้อมูลไม่สำเร็จ');
}

Future<List<dynamic>> searchAnime(String query) async {
  final url = Uri.parse('https://api.jikan.moe/v4/anime?q=$query');
  final res = await http.get(url);
  if (res.statusCode == 200) return jsonDecode(res.body)['data'];
  throw Exception('ค้นหาไม่สำเร็จ');
}

// ==================== Favorites Manager ====================
class FavoritesManager {
  static const String key = "favorites_list";

  static Future<List<Map<String, dynamic>>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(key) ?? [];
    return data.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  static Future<void> addFavorite(Map<String, dynamic> anime) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(key) ?? [];
    if (data.any((item) => jsonDecode(item)['mal_id'] == anime['mal_id']))
      return;
    data.add(jsonEncode(anime));
    await prefs.setStringList(key, data);
  }

  static Future<void> removeFavorite(int malId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(key) ?? [];
    data.removeWhere((item) => jsonDecode(item)['mal_id'] == malId);
    await prefs.setStringList(key, data);
  }

  static Future<bool> isFavorite(int malId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(key) ?? [];
    return data.any((item) => jsonDecode(item)['mal_id'] == malId);
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<dynamic>> _animeList;

  @override
  void initState() {
    super.initState();
    _animeList = getNowAiring();
  }

  String getTitle(Map<String, dynamic> anime) =>
      animeThaiMapping[anime['mal_id']]?['title'] ?? anime['title'];

  String getSynopsis(Map<String, dynamic> anime) =>
      animeThaiMapping[anime['mal_id']]?['synopsis'] ?? anime['synopsis'] ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('อนิเมะกำลังฉาย'),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _animeList,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
          }

          final animeList = snapshot.data ?? [];
          if (animeList.isEmpty)
            return const Center(child: Text('ไม่มีข้อมูล'));

          // ใช้ SliverGrid + SingleChildScrollView จะ scroll ได้ยาว
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner ตัวแรก
                if (animeList.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      final anime = animeList[0];
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AnimeDetailScreen(
                            anime: anime,
                            title: getTitle(anime),
                            synopsis: getSynopsis(anime),
                          ),
                        ),
                      );
                    },
                    child: Stack(
                      children: [
                        Container(
                          height: 220,
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            image: DecorationImage(
                              image: NetworkImage(
                                animeList[0]['images']['jpg']['large_image_url'],
                              ),
                              fit: BoxFit.cover,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black38,
                                blurRadius: 10,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                        ),
                        // Gradient overlay
                        Container(
                          height: 220,
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withOpacity(0.6),
                                Colors.transparent,
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          left: 16,
                          child: Text(
                            getTitle(animeList[0]),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 4),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),
                // Grid อนิเมะ
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: animeList.length - 1,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemBuilder: (context, index) {
                      final anime = animeList[index + 1]; // เพราะ banner ใช้ 0
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AnimeDetailScreen(
                                anime: anime,
                                title: getTitle(anime),
                                synopsis: getSynopsis(anime),
                              ),
                            ),
                          );
                        },
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image.network(
                                anime['images']['jpg']['image_url'],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                            // Gradient overlay
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withOpacity(0.6),
                                    Colors.transparent,
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              left: 8,
                              right: 8,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    getTitle(anime),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${anime['score'] ?? "-"} / 10',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ==================== Search Screen ====================
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<dynamic> _searchResults = [];
  List<Map<String, dynamic>> _recentAnime = [];
  List<dynamic> _suggestions = []; // ✅ เพิ่ม suggestions
  bool _loading = false;
  int? _selectedYear;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadRecentAnime();
  }

  Future<void> _loadRecentAnime() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('recent_anime') ?? [];
    setState(() {
      _recentAnime = data
          .map((e) => jsonDecode(e) as Map<String, dynamic>)
          .toList();
    });
  }

  Future<void> _addRecentAnime(Map<String, dynamic> anime) async {
    final prefs = await SharedPreferences.getInstance();
    _recentAnime.removeWhere((a) => a['mal_id'] == anime['mal_id']);
    _recentAnime.insert(0, anime);
    if (_recentAnime.length > 10) _recentAnime = _recentAnime.sublist(0, 10);
    await prefs.setStringList(
      'recent_anime',
      _recentAnime.map((e) => jsonEncode(e)).toList(),
    );
    setState(() {});
  }

  Future<void> _clearRecentAnime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_anime');
    setState(() {
      _recentAnime.clear();
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        setState(() {
          _searchResults = [];
          _suggestions = [];
          _loading = false;
        });
        return;
      }

      setState(() => _loading = true);
      try {
        final results = await searchAnime(query);

        // กรองปี
        final filteredResults = _selectedYear == null
            ? results
            : results
                  .where(
                    (anime) =>
                        anime['year'] != null && anime['year'] == _selectedYear,
                  )
                  .toList();

        setState(() {
          _searchResults = filteredResults;
          _suggestions = results.take(5).toList(); // เอา top 5 เป็น suggestions
          _loading = false;
        });
      } catch (_) {
        setState(() {
          _searchResults = [];
          _suggestions = [];
          _loading = false;
        });
      }
    });
  }

  String getTitle(Map<String, dynamic> anime) {
    return animeThaiMapping[anime['mal_id']]?['title'] ?? anime['title'];
  }

  String getSynopsis(Map<String, dynamic> anime) {
    return animeThaiMapping[anime['mal_id']]?['synopsis'] ??
        anime['synopsis'] ??
        '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ค้นหาอนิเมะ'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          // แถวค้นหาพร้อมกรองปี
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: _onSearchChanged,
                    decoration: const InputDecoration(
                      hintText: 'พิมพ์ชื่ออนิเมะ...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<int?>(
                    value: _selectedYear,
                    decoration: const InputDecoration(
                      labelText: 'ปี',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('ทั้งหมด'),
                      ),
                      for (int year = DateTime.now().year; year >= 1980; year--)
                        DropdownMenuItem<int?>(
                          value: year,
                          child: Text(year.toString()),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedYear = value;
                      });
                      _onSearchChanged(_controller.text);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Suggestions แสดงใต้ TextField
          if (_focusNode.hasFocus && _suggestions.isNotEmpty)
            Container(
              height: 150,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ListView.builder(
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final anime = _suggestions[index];
                  return ListTile(
                    title: Text(getTitle(anime)),
                    onTap: () {
                      _controller.text = getTitle(anime);
                      _focusNode.unfocus();
                      _onSearchChanged(_controller.text);
                    },
                  );
                },
              ),
            ),

          // Recent Anime
          if (_recentAnime.isNotEmpty && _controller.text.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ค้นหาเมื่อเร็ว ๆ นี้',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: _clearRecentAnime,
                        child: const Text(
                          'ลบทั้งหมด',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 200,
                    child: GridView.builder(
                      scrollDirection: Axis.horizontal,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 1,
                            childAspectRatio: 0.7,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: _recentAnime.length,
                      itemBuilder: (context, index) {
                        final anime = _recentAnime[index];
                        return AnimeCard(
                          anime: anime,
                          getTitle: getTitle,
                          getSynopsis: getSynopsis,
                          onTap: () => _addRecentAnime(anime),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // ผลลัพธ์ search
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: _searchResults.isEmpty
                  ? const Center(child: Text('ไม่พบอนิเมะ'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.65,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final anime = _searchResults[index];
                        return AnimeCard(
                          anime: anime,
                          getTitle: getTitle,
                          getSynopsis: getSynopsis,
                          onTap: () => _addRecentAnime(anime),
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }
}

// ==================== AnimeCard ====================
class AnimeCard extends StatefulWidget {
  final Map<String, dynamic> anime;
  final String Function(Map<String, dynamic>) getTitle;
  final String Function(Map<String, dynamic>) getSynopsis;
  final VoidCallback? onTap;

  const AnimeCard({
    super.key,
    required this.anime,
    required this.getTitle,
    required this.getSynopsis,
    this.onTap,
  });

  @override
  State<AnimeCard> createState() => _AnimeCardState();
}

class _AnimeCardState extends State<AnimeCard> {
  bool _isFav = false;

  @override
  void initState() {
    super.initState();
    _checkFav();
  }

  Future<void> _checkFav() async {
    final fav = await FavoritesManager.isFavorite(widget.anime['mal_id']);
    setState(() => _isFav = fav);
  }

  Future<void> _toggleFav() async {
    if (_isFav) {
      await FavoritesManager.removeFavorite(widget.anime['mal_id']);
    } else {
      await FavoritesManager.addFavorite(widget.anime);
    }
    _checkFav();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.getTitle(widget.anime);
    final synopsis = widget.getSynopsis(widget.anime);

    return GestureDetector(
      onTap: () {
        if (widget.onTap != null) widget.onTap!();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AnimeDetailScreen(
              anime: widget.anime,
              title: title,
              synopsis: synopsis,
            ),
          ),
        );
      },
      child: Stack(
        children: [
          // รูปภาพ + shadow + rounded
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.network(
              widget.anime['images']['jpg']['image_url'],
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: LinearGradient(
                colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
          // Text + score + favorite
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.anime['score'] ?? "-"} / 10',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    const Spacer(),
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          _isFav ? Icons.favorite : Icons.favorite_border,
                          color: Colors.red,
                          size: 16,
                        ),
                        onPressed: _toggleFav,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== Detail Screen ====================
class AnimeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> anime;
  final String title;
  final String synopsis;

  const AnimeDetailScreen({
    super.key,
    required this.anime,
    required this.title,
    required this.synopsis,
  });

  @override
  State<AnimeDetailScreen> createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends State<AnimeDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isFav = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkFav();
  }

  Future<void> _checkFav() async {
    final fav = await FavoritesManager.isFavorite(widget.anime['mal_id']);
    setState(() => _isFav = fav);
  }

  Future<void> _toggleFav() async {
    if (_isFav) {
      await FavoritesManager.removeFavorite(widget.anime['mal_id']);
    } else {
      await FavoritesManager.addFavorite(widget.anime);
    }
    _checkFav();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.deepPurple,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "รายละเอียด"),
            Tab(text: "ข้อมูลเพิ่มเติม"),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.redAccent,
        child: Icon(_isFav ? Icons.favorite : Icons.favorite_border),
        onPressed: _toggleFav,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: widget.anime['mal_id'].toString(),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.anime['images']['jpg']['large_image_url'],
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  color: const Color(0xFF23233A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              'คะแนน: ${widget.anime['score'] ?? "-"}/10',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                        const Divider(height: 20, color: Colors.grey),
                        Text(
                          widget.synopsis.isEmpty
                              ? 'ไม่มีคำอธิบาย'
                              : widget.synopsis,
                          style: const TextStyle(fontSize: 16, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Tab 2: ข้อมูลเพิ่มเติม (สามารถปรับเพิ่มได้)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ปีฉาย: ${widget.anime['year'] ?? "-"}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'ประเภท: ${widget.anime['type'] ?? "-"}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'ตอน: ${widget.anime['episodes'] != null ? widget.anime['episodes'].toString() : "-"}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'สถานะ: ${widget.anime['status'] ?? "-"}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Future<List<Map<String, dynamic>>> _favorites;

  @override
  void initState() {
    super.initState();
    _favorites = FavoritesManager.getFavorites();
  }

  String getTitle(Map<String, dynamic> anime) =>
      animeThaiMapping[anime['mal_id']]?['title'] ?? anime['title'];

  String getSynopsis(Map<String, dynamic> anime) =>
      animeThaiMapping[anime['mal_id']]?['synopsis'] ?? anime['synopsis'] ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายการโปรด'),
        backgroundColor: Colors.deepPurple,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _favorites,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final favList = snapshot.data ?? [];
          if (favList.isEmpty) {
            return const Center(child: Text('ยังไม่มีรายการโปรด'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: favList.length,
            itemBuilder: (context, index) {
              final anime = favList[index];
              return AnimeCard(
                anime: anime,
                getTitle: getTitle,
                getSynopsis: getSynopsis,
              );
            },
          );
        },
      ),
    );
  }
}
