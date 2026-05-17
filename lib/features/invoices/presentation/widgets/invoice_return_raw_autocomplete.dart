import 'dart:async';

import 'package:flutter/material.dart';
import 'package:delta_erp/features/invoices/domain/invoice_suggestion.dart';

/// Prefix search field with async suggestions for sales/purchase returns.
class InvoiceReturnRawAutocomplete extends StatefulWidget {
  const InvoiceReturnRawAutocomplete({
    super.key,
    required this.controller,
    required this.searchSuggestions,
    required this.onSuggestionSelected,
    required this.onTextEdited,
    required this.labelText,
    this.hintText,
  });

  final TextEditingController controller;
  final Future<List<InvoiceSuggestion>> Function(String prefix) searchSuggestions;
  final ValueChanged<InvoiceSuggestion> onSuggestionSelected;
  final VoidCallback onTextEdited;
  final String labelText;
  final String? hintText;

  @override
  State<InvoiceReturnRawAutocomplete> createState() =>
      _InvoiceReturnRawAutocompleteState();
}

class _InvoiceReturnRawAutocompleteState extends State<InvoiceReturnRawAutocomplete> {
  late final FocusNode _focusNode = FocusNode();
  List<InvoiceSuggestion> _hits = const [];
  Timer? _debounce;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _kickSearchIfNeeded(sync: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onControllerChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    widget.onTextEdited();
    _kickSearchIfNeeded();
  }

  void _kickSearchIfNeeded({bool sync = false}) {
    final text = widget.controller.text.trim();
    _debounce?.cancel();
    final epoch = ++_epoch;

    if (text.isEmpty) {
      if (_hits.isNotEmpty) {
        setState(() => _hits = const []);
      }
      return;
    }

    void run() async {
      final results = await widget.searchSuggestions(text);
      if (!mounted || epoch != _epoch) return;
      setState(() => _hits = results);
    }

    if (sync) {
      scheduleMicrotask(run);
    } else {
      _debounce = Timer(const Duration(milliseconds: 240), run);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<InvoiceSuggestion>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      displayStringForOption: (s) => s.invoiceNumber,
      optionsBuilder: (value) {
        final t = value.text.trim();
        if (t.isEmpty) {
          return const Iterable<InvoiceSuggestion>.empty();
        }
        return _hits;
      },
      onSelected: (selected) {
        widget.onSuggestionSelected(selected);
        widget.controller.text = selected.invoiceNumber;
        widget.controller.selection = TextSelection.collapsed(
          offset: widget.controller.text.length,
        );
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
          ),
          onTap: () {
            controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: controller.text.length,
            );
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, minWidth: 280),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(option.invoiceNumber),
                    subtitle: Text(
                      '${option.accountLabel} • ID ${option.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
