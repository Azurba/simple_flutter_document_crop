import 'package:flutter/material.dart';
import 'package:flutter_simple_document_crop/crop_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crop Document Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Crop Document Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<String> selectedImg = ['assets/identity.JPG', 'assets/document.JPG'];
  int currentIndex = 0;
  final CropService cropService = CropService();
  void _nextImage() {
    if (currentIndex < selectedImg.length - 1) {
      setState(() {
        currentIndex++;
      });
    }
  }

  void _previousImage() {
    if (currentIndex > 0) {
      setState(() {
        currentIndex--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
        ),
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                        onPressed: currentIndex > 0 ? _previousImage : null,
                        icon: const Icon(
                          Icons.arrow_back_ios_outlined,
                          size: 40,
                        )),
                    const SizedBox(width: 60),
                    IconButton(
                        onPressed: currentIndex < selectedImg.length - 1
                            ? _nextImage
                            : null,
                        icon: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 40,
                        )),
                  ],
                ),
                const SizedBox(height: 30),
                Image.asset(selectedImg[currentIndex]),
                const SizedBox(height: 60),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12)),
                  onPressed: () {
                    cropService.processAndTrimImage(selectedImg[currentIndex]);
                  },
                  icon: const Icon(
                    Icons.crop,
                    color: Colors.white,
                    size: 32,
                  ),
                  label: const Text(
                    'Crop Document',
                    style: TextStyle(color: Colors.white, fontSize: 32),
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}
