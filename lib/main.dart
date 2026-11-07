import 'package:flutter/material.dart';
import 'quiz_page.dart';
import 'store.dart';
import 'teacher_page.dart';

const seed = Color(0xFF7B83C9);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await Store.open();
  runApp(App(store: store));
}

class App extends StatelessWidget {
  const App({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'تمارين الترتيب',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
      ),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: Home(store: store),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key, required this.store});
  final Store store;

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🧩 تمارين الترتيب')),
      body: SafeArea(
        child: IndexedStack(
          index: tab,
          children: [
            QuizPage(store: widget.store),
            TeacherPage(store: widget.store, onChanged: () => setState(() {})),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.quiz_outlined), label: 'الاختبار'),
          NavigationDestination(icon: Icon(Icons.edit_note), label: 'إدارة المعلم'),
        ],
      ),
    );
  }
}