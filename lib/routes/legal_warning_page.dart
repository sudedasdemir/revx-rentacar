import 'package:flutter/material.dart';

class LegalWarningPage extends StatelessWidget {
  const LegalWarningPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Legal Warning")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: const [
            Text(
              "Legal Warning",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              "This Legal Warning governs your access to and use of all content, services, and products provided by RevX via its mobile applications, websites, and other platforms. By using our services, you agree to comply with the following terms and legal restrictions.",
              style: TextStyle(fontSize: 16, height: 1.6),
            ),

            SizedBox(height: 20),
            Text(
              "1. Intellectual Property",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "All logos, trademarks, software, text, graphics, and media on our platform are owned or licensed by RevX and protected by international intellectual property laws. Unauthorized use, reproduction, or distribution is strictly prohibited.",
              style: TextStyle(fontSize: 16, height: 1.6),
            ),

            SizedBox(height: 20),
            Text(
              "2. Limitation of Liability",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "RevX shall not be held liable for any direct, indirect, incidental, or consequential damages arising from the use or inability to use our services, even if we have been advised of the possibility of such damages.",
              style: TextStyle(fontSize: 16, height: 1.6),
            ),

            SizedBox(height: 20),
            Text(
              "3. Accuracy of Information",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "While we strive to ensure all information on our platforms is accurate and up-to-date, we make no warranties as to its completeness or reliability. Users are responsible for verifying any information before relying on it.",
              style: TextStyle(fontSize: 16, height: 1.6),
            ),

            SizedBox(height: 20),
            Text(
              "4. External Links",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "Our services may include links to third-party websites. These links are provided for convenience only. RevX does not control or endorse the content or practices of any third-party sites and assumes no responsibility for them.",
              style: TextStyle(fontSize: 16, height: 1.6),
            ),

            SizedBox(height: 20),
            Text(
              "5. Applicable Law",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "This Legal Warning is governed by and construed in accordance with the laws of the jurisdiction in which RevX is registered. Any disputes arising from its interpretation or execution will be subject to local legal authority.",
              style: TextStyle(fontSize: 16, height: 1.6),
            ),

            SizedBox(height: 30),
            Text(
              "By continuing to use RevX services, you confirm that you have read, understood, and agreed to abide by this Legal Warning.",
              style: TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
