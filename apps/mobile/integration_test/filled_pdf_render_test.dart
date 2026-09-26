// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';

// A synthetic one-page AcroForm with the value VISIBLE FORM VALUE.
// Kept inline so the fixture is not bundled into production assets.
const String _filledFormBase64 =
    'JVBERi0xLjMKJeLjz9MKMSAwIG9iago8PAovQWNyb0Zvcm0gMiAwIFIKL1BhZ2VNb2RlIC9Vc2VOb25lCi9QYWdlcyA5IDAgUgov'
    'VHlwZSAvQ2F0YWxvZwo+PgplbmRvYmoKMiAwIG9iago8PAovREEgKFwwNTdIZWx2IDAgVGYgMCBnKQovRFIgPDwKL0VuY29kaW5n'
    'IDw8Ci9STEFGZW5jb2RpbmcgMyAwIFIKPj4KL0ZvbnQgPDwKL0hlbHYgNCAwIFIKPj4KPj4KL0ZpZWxkcyBbIDUgMCBSIF0KL05l'
    'ZWRBcHBlYXJhbmNlcyBmYWxzZQo+PgplbmRvYmoKMyAwIG9iago8PAovVHlwZSAvRW5jb2RpbmcKL0RpZmZlcmVuY2VzIFsgMjQg'
    'L2JyZXZlIC9jYXJvbiAvY2lyY3VtZmxleCAvZG90YWNjZW50IC9odW5nYXJ1bWxhdXQgL29nb25layAvcmluZyAvdGlsZGUgMzkg'
    'L3F1b3Rlc2luZ2xlIDk2IC9ncmF2ZSAxMjggL2J1bGxldCAvZGFnZ2VyIC9kYWdnZXJkYmwgL2VsbGlwc2lzIC9lbWRhc2ggL2Vu'
    'ZGFzaCAvZmxvcmluIC9mcmFjdGlvbiAvZ3VpbHNpbmdsbGVmdCAvZ3VpbHNpbmdscmlnaHQgL21pbnVzIC9wZXJ0aG91c2FuZCAv'
    'cXVvdGVkYmxiYXNlIC9xdW90ZWRibGxlZnQgL3F1b3RlZGJscmlnaHQgL3F1b3RlbGVmdCAvcXVvdGVyaWdodCAvcXVvdGVzaW5n'
    'bGJhc2UgL3RyYWRlbWFyayAvZmkgL2ZsIC9Mc2xhc2ggL09FIC9TY2Fyb24gL1lkaWVyZXNpcyAvWmNhcm9uIC9kb3RsZXNzaSAv'
    'bHNsYXNoIC9vZSAvc2Nhcm9uIC96Y2Fyb24gMTYwIC9FdXJvIDE2NCAvY3VycmVuY3kgMTY2IC9icm9rZW5iYXIgMTY4IC9kaWVy'
    'ZXNpcyAvY29weXJpZ2h0IC9vcmRmZW1pbmluZSAxNzIgL2xvZ2ljYWxub3QgLy5ub3RkZWYgL3JlZ2lzdGVyZWQgL21hY3JvbiAv'
    'ZGVncmVlIC9wbHVzbWludXMgL3R3b3N1cGVyaW9yIC90aHJlZXN1cGVyaW9yIC9hY3V0ZSAvbXUgMTgzIC9wZXJpb2RjZW50ZXJl'
    'ZCAvY2VkaWxsYSAvb25lc3VwZXJpb3IgL29yZG1hc2N1bGluZSAxODggL29uZXF1YXJ0ZXIgL29uZWhhbGYgL3RocmVlcXVhcnRl'
    'cnMgMTkyIC9BZ3JhdmUgL0FhY3V0ZSAvQWNpcmN1bWZsZXggL0F0aWxkZSAvQWRpZXJlc2lzIC9BcmluZyAvQUUgL0NjZWRpbGxh'
    'IC9FZ3JhdmUgL0VhY3V0ZSAvRWNpcmN1bWZsZXggL0VkaWVyZXNpcyAvSWdyYXZlIC9JYWN1dGUgL0ljaXJjdW1mbGV4IC9JZGll'
    'cmVzaXMgL0V0aCAvTnRpbGRlIC9PZ3JhdmUgL09hY3V0ZSAvT2NpcmN1bWZsZXggL090aWxkZSAvT2RpZXJlc2lzIC9tdWx0aXBs'
    'eSAvT3NsYXNoIC9VZ3JhdmUgL1VhY3V0ZSAvVWNpcmN1bWZsZXggL1VkaWVyZXNpcyAvWWFjdXRlIC9UaG9ybiAvZ2VybWFuZGJs'
    'cyAvYWdyYXZlIC9hYWN1dGUgL2FjaXJjdW1mbGV4IC9hdGlsZGUgL2FkaWVyZXNpcyAvYXJpbmcgL2FlIC9jY2VkaWxsYSAvZWdy'
    'YXZlIC9lYWN1dGUgL2VjaXJjdW1mbGV4IC9lZGllcmVzaXMgL2lncmF2ZSAvaWFjdXRlIC9pY2lyY3VtZmxleCAvaWRpZXJlc2lz'
    'IC9ldGggL250aWxkZSAvb2dyYXZlIC9vYWN1dGUgL29jaXJjdW1mbGV4IC9vdGlsZGUgL29kaWVyZXNpcyAvZGl2aWRlIC9vc2xh'
    'c2ggL3VncmF2ZSAvdWFjdXRlIC91Y2lyY3VtZmxleCAvdWRpZXJlc2lzIC95YWN1dGUgL3Rob3JuIC95ZGllcmVzaXMgXQo+Pgpl'
    'bmRvYmoKNCAwIG9iago8PAovQmFzZUZvbnQgL0hlbHZldGljYQovU3VidHlwZSAvVHlwZTEKL05hbWUgL0hlbHYKL1R5cGUgL0Zv'
    'bnQKL0VuY29kaW5nIDMgMCBSCj4+CmVuZG9iago1IDAgb2JqCjw8Ci9BUCA8PAovTiA2IDAgUgo+PgovQlMgPDwKL1MgL1MKL1cg'
    'MQo+PgovREEgKFwwNTdIZWx2IDEyIFRmIFwwNTYxIFwwNTYxIFwwNTYxIHJnKQovRFYgKCkKL0YgNAovRlQgL1R4Ci9GZiAwCi9N'
    'SyA8PAovQkMgWyAwLjEgMC4xIDAuMSBdCi9CRyBbIDAuOCAwLjg0MyAxIF0KPj4KL01heExlbiAxMDAKL1AgNyAwIFIKL1JlY3Qg'
    'WyA3MiA2OTAgMzcyIDcxNSBdCi9TdWJ0eXBlIC9XaWRnZXQKL1QgKGV4YW1wbGUpCi9UVSAoZXhhbXBsZSkKL1R5cGUgL0Fubm90'
    'Ci9WIChWSVNJQkxFIEZPUk0gVkFMVUUpCj4+CmVuZG9iago2IDAgb2JqCjw8Ci9UeXBlIC9YT2JqZWN0Ci9TdWJ0eXBlIC9Gb3Jt'
    'Ci9CQm94IFsgMC4wIDAuMCAzMDAgMjUgXQovTGVuZ3RoIDEwOAovUmVzb3VyY2VzIDw8Ci9Gb250IDw8Ci9IZWx2IDQgMCBSCj4+'
    'Cj4+Ci9Gb3JtVHlwZSAxCi9NYXRyaXggWyAxIDAgMCAxIDAgMCBdCj4+CnN0cmVhbQpxCi9UeCBCTUMgCnEKMiAxIDI5Ni4wIDIz'
    'LjAgcmUKVwpCVAovSGVsdiAxMi4wIFRmIC4xIC4xIC4xIHJnCjIgOC4xOTIgVGQKKFZJU0lCTEUgRk9STSBWQUxVRSkgVGoKRVQK'
    'UQpFTUMKUQoKZW5kc3RyZWFtCmVuZG9iago3IDAgb2JqCjw8Ci9Bbm5vdHMgWyA1IDAgUiBdCi9Db250ZW50cyA4IDAgUgovTWVk'
    'aWFCb3ggWyAwIDAgNTk1IDg0MiBdCi9QYXJlbnQgOSAwIFIKL1Jlc291cmNlcyA8PAovRm9udCAxMCAwIFIKL1Byb2NTZXQgWyAv'
    'UERGIC9UZXh0IC9JbWFnZUIgL0ltYWdlQyAvSW1hZ2VJIF0KPj4KL1JvdGF0ZSAwCi9UcmFucyA8PAo+PgovVHlwZSAvUGFnZQo+'
    'PgplbmRvYmoKOCAwIG9iago8PAovRmlsdGVyIFsgL0FTQ0lJODVEZWNvZGUgL0ZsYXRlRGVjb2RlIF0KL0xlbmd0aCAxMjkKPj4K'
    'c3RyZWFtCkdhcFFoMEU9RiwwVVxIM1RccE5ZVF5RS2s/dGM+SVAsO1cjVTFeMjNpaFBFTV8/Q1QzIixnQ0spJ1FwLVRna0NnLkA/'
    'U0IuInBZMkJFVkUhUSI2XFZBMHJmMFxAPHVgalZSIy5QYl0oXUJJXFtHLj4yQWNvSTRfWyEqIVNOSmN+PgplbmRzdHJlYW0KZW5k'
    'b2JqCjkgMCBvYmoKPDwKL0NvdW50IDEKL0tpZHMgWyA3IDAgUiBdCi9UeXBlIC9QYWdlcwo+PgplbmRvYmoKMTAgMCBvYmoKPDwK'
    'L0YxIDExIDAgUgo+PgplbmRvYmoKMTEgMCBvYmoKPDwKL0Jhc2VGb250IC9IZWx2ZXRpY2EKL0VuY29kaW5nIC9XaW5BbnNpRW5j'
    'b2RpbmcKL05hbWUgL0YxCi9TdWJ0eXBlIC9UeXBlMQovVHlwZSAvRm9udAo+PgplbmRvYmoKMTIgMCBvYmoKPDwKL0F1dGhvciAo'
    'YW5vbnltb3VzKQovQ3JlYXRpb25EYXRlIChEXDA3MjIwMjYwOTI0MTQyMzI1XDA1MzAyXDA0NzAwXDA0NykKL0NyZWF0b3IgKGFu'
    'b255bW91cykKL0tleXdvcmRzICgpCi9Nb2REYXRlIChEXDA3MjIwMjYwOTI0MTQyMzI1XDA1MzAyXDA0NzAwXDA0NykKL1Byb2R1'
    'Y2VyIChSZXBvcnRMYWIgUERGIExpYnJhcnkgXDA1NSBcMDUwb3BlbnNvdXJjZVwwNTEpCi9TdWJqZWN0ICh1bnNwZWNpZmllZCkK'
    'L1RpdGxlICh1bnRpdGxlZCkKL1RyYXBwZWQgL0ZhbHNlCj4+CmVuZG9iagp4cmVmCjAgMTMKMDAwMDAwMDAwMCA2NTUzNSBmIAow'
    'MDAwMDAwMDE1IDAwMDAwIG4gCjAwMDAwMDAwOTkgMDAwMDAgbiAKMDAwMDAwMDI1NSAwMDAwMCBuIAowMDAwMDAxNTgxIDAwMDAw'
    'IG4gCjAwMDAwMDE2NzkgMDAwMDAgbiAKMDAwMDAwMTk4NSAwMDAwMCBuIAowMDAwMDAyMjc2IDAwMDAwIG4gCjAwMDAwMDI0ODQg'
    'MDAwMDAgbiAKMDAwMDAwMjcwNCAwMDAwMCBuIAowMDAwMDAyNzYzIDAwMDAwIG4gCjAwMDAwMDI3OTYgMDAwMDAgbiAKMDAwMDAw'
    'MjkwNCAwMDAwMCBuIAp0cmFpbGVyCjw8Ci9TaXplIDEzCi9Sb290IDEgMCBSCi9JbmZvIDEyIDAgUgovSUQgWyA8Mjc3MDZkMWIw'
    'NmQ4NjNmYzQ4MDBlYTIyYjE1MTZhYmU+IDwyNzcwNmQxYjA2ZDg2M2ZjNDgwMGVhMjJiMTUxNmFiZT4gXQo+PgpzdGFydHhyZWYK'
    'MzE5NAolJUVPRgo=';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('filled form text is painted on device', (tester) async {
    await pdfrxFlutterInitialize();
    final PdfDocument document = await PdfDocument.openData(
      base64Decode(_filledFormBase64),
      sourceName: 'synthetic-form',
    );
    try {
      final PdfPage page = document.pages.single;
      final PdfImage? pageOnly = await page.render(
        annotationRenderingMode: PdfAnnotationRenderingMode.none,
      );
      final PdfImage? withForm = await page.render(
        annotationRenderingMode: PdfAnnotationRenderingMode.annotationAndForms,
      );
      expect(pageOnly, isNotNull);
      expect(withForm, isNotNull);
      try {
        int darkPixels(PdfImage image) {
          int count = 0;
          // Interior of the field, excluding its border. At 72 dpi this is
          // x=72..372 and y=127..152 from the top of the page.
          for (int y = 131; y < 149; y++) {
            for (int x = 80; x < 360; x++) {
              final int index = (y * image.width + x) * 4;
              if (image.pixels[index] < 180 &&
                  image.pixels[index + 1] < 180 &&
                  image.pixels[index + 2] < 180) {
                count++;
              }
            }
          }
          return count;
        }

        expect(darkPixels(pageOnly!), 0);
        expect(darkPixels(withForm!), greaterThan(40));
      } finally {
        pageOnly?.dispose();
        withForm?.dispose();
      }
    } finally {
      await document.dispose();
    }
  });
}
