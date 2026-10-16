import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../data/building/address_catalog.dart';
import 'glass_widgets.dart';

@Preview(name: 'נייבור · בחירת כתובת', size: Size(390, 844))
Widget addressPickerPreview() => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: buildingTheme(),
  home: Scaffold(
    body: Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AddressPicker(onChanged: (_) {}),
      ),
    ),
  ),
);

/// Reference streets help with spelling; a new/unlisted address can be entered.
class AddressPicker extends StatefulWidget {
  const AddressPicker({super.key, required this.onChanged, this.catalog});
  final ValueChanged<String> onChanged;
  final AddressCatalog? catalog;
  @override
  State<AddressPicker> createState() => _AddressPickerState();
}

class _AddressPickerState extends State<AddressPicker> {
  final input = TextEditingController(), number = TextEditingController();
  final focus = FocusNode(), numberFocus = FocusNode();
  AddressChoice? selected;
  @override
  void initState() {
    super.initState();
    input.addListener(_inputChanged);
    number.addListener(_emit);
  }

  void _inputChanged() {
    if (selected != null && input.text != selected!.label) {
      setState(() => selected = null);
      number.clear();
    }
    _emit();
  }

  String get value {
    if (input.text.trim().isEmpty) return '';
    if (selected != null) {
      return '${selected!.street} ${number.text.trim()}, ${selected!.city}';
    }
    final parts = input.text.trim().split(',');
    return parts.length == 2
        ? '${parts.first.trim()} ${number.text.trim()}, ${parts.last.trim()}'
        : '${input.text.trim()} ${number.text.trim()}'.trim();
  }

  void _emit() => widget.onChanged(value);

  FutureOr<Iterable<AddressChoice>> _options(TextEditingValue value) {
    if (value.text.trim().length < 2) return const [];
    final catalog = widget.catalog ?? AddressCatalog.cached;
    if (catalog != null) return catalog.search(value.text);
    return AddressCatalog.load()
        .then<Iterable<AddressChoice>>((index) => index.search(value.text))
        .catchError((Object _) => const <AddressChoice>[]);
  }

  @override
  void dispose() {
    input.dispose();
    number.dispose();
    focus.dispose();
    numberFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RawAutocomplete<AddressChoice>(
        textEditingController: input,
        focusNode: focus,
        displayStringForOption: (option) => option.label,
        optionsBuilder: _options,
        onSelected: (option) {
          setState(() => selected = option);
          _emit();
          numberFocus.requestFocus();
        },
        fieldViewBuilder: (context, controller, fieldFocus, submit) =>
            TextFormField(
              key: const Key('building-address'),
              controller: controller,
              focusNode: fieldFocus,
              maxLength: 100,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'רחוב ועיר',
                hintText: 'רחוב ועיר',
                counterText: '',
              ),
              validator: (_) => value.isEmpty
                  ? 'יש להזין כתובת'
                  : value.length > 100
                  ? 'הכתובת ארוכה מדי'
                  : null,
            ),
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topRight,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            color: const Color(0xFFF5FAFB),
            child: SizedBox(
              width: (MediaQuery.sizeOf(context).width - 48).clamp(200, 592),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, i) {
                    final option = options.elementAt(i);
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: const Icon(
                        Icons.location_on_outlined,
                        color: glassTeal,
                        size: 20,
                      ),
                      title: Text(option.street),
                      subtitle: Text(option.city),
                      onTap: () => onSelected(option),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
      ...[
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('building-house-number'),
          controller: number,
          focusNode: numberFocus,
          maxLength: 40,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'מספר בית / זיהוי הבניין',
            hintText: 'למשל: 216 או 216 כניסה א׳',
            helperText: 'טקסט חופשי — אפשר לציין גם כניסה לבניין.',
            counterText: '',
          ),
          validator: (text) =>
              text == null || text.trim().isEmpty ? 'יש להזין מספר בית' : null,
        ),
      ],
      const SizedBox(height: 6),
      Text(
        selected == null
            ? 'בחרו רחוב ועיר מהרשימה, או הקלידו אותם ידנית.'
            : 'מקור הרחובות: רשות האוכלוסין וההגירה · data.gov.il',
        style: const TextStyle(fontSize: 11, color: glassMuted),
      ),
    ],
  );
}
