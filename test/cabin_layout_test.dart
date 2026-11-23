import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/cabin_layout.dart';

void main() {
  test('cabin layout references existing assets inside the frame', () {
    final json =
        jsonDecode(File(CabinLayout.assetPath).readAsStringSync())
            as Map<String, dynamic>;
    final layout = CabinLayout.fromJson(json);

    void inFrame(CabinRect r, String name) {
      for (final v in [r.left, r.top, r.width, r.height]) {
        expect(v, inInclusiveRange(0, 1), reason: name);
      }
      expect(r.left + r.width, lessThanOrEqualTo(1.0001), reason: name);
      expect(r.top + r.height, lessThanOrEqualTo(1.0001), reason: name);
    }

    expect(File(layout.baseImage).existsSync(), isTrue);
    expect(layout.layers.keys.toSet(), CabinLayout.layerIds.toSet());
    for (final entry in layout.layers.entries) {
      inFrame(entry.value.rect, entry.key);
      for (final r in entry.value.rects ?? const <CabinRect>[]) {
        inFrame(r, '${entry.key} stage rect');
      }
      for (final image in entry.value.images) {
        expect(File(image).existsSync(), isTrue, reason: image);
      }
    }
    for (final slot in ['rug', 'curtain', 'lamp']) {
      expect(layout.layers[slot]!.images, hasLength(3), reason: slot);
    }
    for (final growth in ['books', 'plant']) {
      expect(layout.layers[growth]!.images, hasLength(3), reason: growth);
    }
    expect(layout.layers['books']!.rects, hasLength(3));
    inFrame(layout.character, 'character');
    inFrame(layout.questBoard, 'questBoard');
    expect(layout.doors.keys.toSet(), {'family', 'group'});
  });
}
