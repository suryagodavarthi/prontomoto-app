// report_preview_page.dart
// The report, shown inside the app, as the portal's Preview PDF shows it in the
// page: readable and zoomable, but with nothing to save it from. Saving is the
// Download button's job, and that opens only once the case is approved, because
// an unapproved report is indistinguishable from a final one.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

/// What the person chose in the preview.
enum ReportPreviewAction { approve, download }

class ReportPreviewPage extends StatefulWidget {
  final Uint8List pdfBytes;
  final String vehicleNumber;
  final bool caseApproved;

  /// Final report staff and admins may approve from here, as on the portal.
  final bool canApprove;

  const ReportPreviewPage({
    super.key,
    required this.pdfBytes,
    required this.vehicleNumber,
    required this.caseApproved,
    required this.canApprove,
  });

  @override
  State<ReportPreviewPage> createState() => _ReportPreviewPageState();
}

class _ReportPreviewPageState extends State<ReportPreviewPage> {
  late final PdfControllerPinch _controller =
      PdfControllerPinch(document: PdfDocument.openData(widget.pdfBytes));
  int _page = 1;
  int _pages = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Report preview — ${widget.vehicleNumber}", style: const TextStyle(fontSize: 16)),
        actions: [
          if (_pages > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text("$_page / $_pages"),
              ),
            ),
        ],
      ),
      body: PdfViewPinch(
        controller: _controller,
        onDocumentLoaded: (doc) => setState(() => _pages = doc.pagesCount),
        onPageChanged: (page) => setState(() => _page = page),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade300))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              widget.caseApproved
                  ? "✅ Case approved — the download is unlocked."
                  : "🔒 Check the report, then approve the case to unlock the download.",
              style: TextStyle(fontSize: 12.5, color: widget.caseApproved ? Colors.green.shade700 : Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close"),
                ),
              ),
              if (!widget.caseApproved && widget.canApprove) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                    onPressed: () => Navigator.pop(context, ReportPreviewAction.approve),
                    child: const Text("Approve Case"),
                  ),
                ),
              ],
              if (widget.caseApproved) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, ReportPreviewAction.download),
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text("Download PDF"),
                  ),
                ),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}
