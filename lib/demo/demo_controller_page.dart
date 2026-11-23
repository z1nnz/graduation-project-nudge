import 'package:flutter/material.dart';

import 'demo_controller.dart';
import 'generated_demo_contract.dart';

class DemoCharacter extends StatelessWidget {
  const DemoCharacter({super.key, required this.pose, this.size = 96});
  final String pose;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _PosePainter(pose)),
  );
}

class _PosePainter extends CustomPainter {
  _PosePainter(this.pose);
  final String pose;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64, size.height / 64);
    for (final m in demoPoseMarks[pose] ?? demoPoseMarks['idle']!) {
      final paint = Paint()
        ..color = Color(demoPalette[m.ink]!)
        ..strokeWidth = 1;
      if (m.kind == 'circle') {
        canvas.drawCircle(
          Offset(m.x.toDouble(), m.y.toDouble()),
          m.a.toDouble(),
          paint,
        );
      } else {
        canvas.drawLine(
          Offset(m.x.toDouble(), m.y.toDouble()),
          Offset(m.a.toDouble(), m.b.toDouble()),
          paint,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PosePainter oldDelegate) => oldDelegate.pose != pose;
}

class DemoControllerPage extends StatefulWidget {
  const DemoControllerPage({super.key, this.controller});
  final DemoController? controller;
  @override
  State<DemoControllerPage> createState() => _DemoControllerPageState();
}

class _DemoControllerPageState extends State<DemoControllerPage> {
  late final DemoController controller =
      widget.controller ??
      DemoController(
        transport: PlatformDemoTransport(),
        acceptance: DemoAcceptance.build(),
      );
  String previewPose = 'idle';
  @override
  void dispose() {
    if (widget.controller == null) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Prototype Demo Controller')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'DEMO · 固定原型資料',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('一次連接一台。連線失敗時，繼續使用裝置自動展示。'),
            if (!controller.acceptance.allowed)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('藍牙連動尚待實機驗收；目前可查看角色原型。'),
              ),
            for (final device in DemoDevice.values)
              Card(
                child: ListTile(
                  title: Text(demoDeviceNames[device.name]!),
                  subtitle: Text(
                    controller.device == device
                        ? switch (controller.connection) {
                            DemoConnection.connecting => '連線中',
                            DemoConnection.connected => '已連線',
                            DemoConnection.disconnected => '未連線',
                          }
                        : '未連線',
                  ),
                  trailing: FilledButton(
                    onPressed:
                        controller.acceptance.allowed &&
                            !controller.busy &&
                            controller.connection == DemoConnection.disconnected
                        ? () => controller.connect(device)
                        : null,
                    child: const Text('連線'),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              controller.message,
              key: const Key('demo-status'),
              semanticsLabel: controller.message,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final action in demoActions)
                  FilledButton.tonal(
                    key: Key('demo-$action'),
                    onPressed: controller.canSend
                        ? () => controller.send(action)
                        : null,
                    child: Text(switch (action) {
                      'next' => 'Next',
                      'restart' => 'Restart',
                      _ => 'Start Focus',
                    }),
                  ),
                TextButton(
                  onPressed:
                      controller.connection != DemoConnection.disconnected
                      ? controller.disconnect
                      : null,
                  child: const Text('中斷連線'),
                ),
              ],
            ),
            const Divider(height: 32),
            const Text('角色預覽 · DEMO'),
            Center(
              child: DemoCharacter(
                pose: controller.reported?.pose ?? previewPose,
                size: 120,
              ),
            ),
            DropdownButton<String>(
              value: previewPose,
              isExpanded: true,
              items: demoPoseMarks.keys
                  .map(
                    (pose) => DropdownMenuItem(
                      value: pose,
                      child: Text(pose.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: controller.reported == null
                  ? (pose) {
                      if (pose != null) setState(() => previewPose = pose);
                    }
                  : null,
            ),
            if (controller.reported case final state?)
              Text('裝置回報：${state.scene.toUpperCase()} · DEMO'),
          ],
        ),
      ),
    ),
  );
}
