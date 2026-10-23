import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/widgets/focusable.dart';

void main() {
  testWidgets('Klickbare Elemente sind für Bildschirmleser Knöpfe mit Namen', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            Focusable(
              onTap: () {},
              builder: (_, _) => const Column(children: [Text('Atlas'), Text('2022')]),
            ),
            Focusable(
              onTap: () {},
              semanticLabel: 'Theme Midnight',
              builder: (_, _) => const SizedBox(width: 50, height: 50),
            ),
          ],
        ),
      ),
    );

    final card = tester.getSemantics(find.byType(Focusable).first);
    expect(card.label, 'Atlas\n2022', reason: 'Name aus dem sichtbaren Text');
    expect(card.flagsCollection.isButton, isTrue);

    final tile = tester.getSemantics(find.byType(Focusable).last);
    expect(tile.label, 'Theme Midnight');
    handle.dispose();
  });
}
