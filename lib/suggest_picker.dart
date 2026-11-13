import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'location_service.dart';
import 'logo_service.dart';
import 'suggest_engine.dart';

const Color _brandBlue = Color(0xFF1D6FDC);
const Color _grey = Color(0xFF8E8E8E);
const Color _fill = Color(0xFFF2F2F2);
const Color _chipFill = Color(0xFFE8F0FC);

const int _kMaxRows = 6;

/// A search box with a live suggestion list under it.
///
/// Type "J" and every name starting with J is listed; keep typing and the list
/// narrows until you see yours. Tap a row to pick it. Anything that is not in
/// the list can be added exactly as typed.
///
/// With [multi] set, each pick becomes a chip and the box stays open for the
/// next one. [onChanged] always reports the value ready to save, so the editor
/// does not need to know how the picker works inside.
class SuggestPicker extends StatefulWidget {
  final SuggestKind kind;
  final bool multi;
  final String initialValue;
  final int maxLength;
  final bool autofocus;
  final String? errorText;
  final ValueChanged<String> onChanged;

  const SuggestPicker({
    super.key,
    required this.kind,
    required this.initialValue,
    required this.onChanged,
    this.multi = false,
    this.maxLength = 80,
    this.autofocus = false,
    this.errorText,
  });

  @override
  State<SuggestPicker> createState() => _SuggestPickerState();
}

class _SuggestPickerState extends State<SuggestPicker> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  final List<String> _chosen = <String>[];

  List<SuggestEntry> _results = const <SuggestEntry>[];
  bool _open = false;
  int _ticket = 0;
  Timer? _debounce;

  SuggestService get _service => SuggestService.instance;

  @override
  void initState() {
    super.initState();
    if (widget.multi) {
      _chosen.addAll(splitMulti(widget.initialValue));
    } else {
      _controller.text = widget.initialValue;
    }
    _results = _service.searchLocal(widget.kind, '', exclude: _chosen.toSet(), limit: _kMaxRows);
    _focus.addListener(_onFocusChanged);
    if (widget.autofocus) {
      _open = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ---- value ----

  List<String> get _items {
    final pending = _controller.text.trim();
    final items = <String>[..._chosen];
    if (widget.multi && pending.isNotEmpty) items.add(pending);
    return items;
  }

  int get _length => widget.multi ? joinMulti(_items).length : _controller.text.length;

  void _emit() {
    if (widget.multi) {
      widget.onChanged(joinMulti(_items));
    } else {
      widget.onChanged(_controller.text.trim());
    }
  }

  // ---- searching ----

  void _refresh() {
    final query = _controller.text;
    final exclude = _chosen.toSet();
    final local = _service.searchLocal(widget.kind, query, exclude: exclude, limit: _kMaxRows);
    setState(() => _results = local);

    _debounce?.cancel();
    final ticket = ++_ticket;
    if (query.trim().length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final remote = await _service.searchRemote(widget.kind, query);
      if (!mounted || ticket != _ticket || remote.isEmpty) return;
      setState(() {
        _results = _service.merge(_results, remote, exclude: exclude, limit: _kMaxRows + 4);
      });
    });
  }

  void _onFocusChanged() {
    if (_focus.hasFocus) {
      if (!widget.multi && _controller.text.isNotEmpty) {
        _controller.selection =
            TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
      }
      setState(() => _open = true);
      _refresh();
    } else {
      setState(() => _open = false);
    }
  }

  void _onTyped(String _) {
    if (!_open) _open = true;
    _refresh();
    _emit();
  }

  // ---- picking ----

  bool _fits(String value) {
    final next = joinMulti([..._chosen, value]).length;
    if (next <= widget.maxLength) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('That is the most you can add (${widget.maxLength} characters)')),
    );
    return false;
  }

  void _pick(SuggestEntry entry) {
    final value = entry.value.trim();
    if (value.isEmpty) return;
    if (entry.logo.isNotEmpty &&
        (widget.kind == SuggestKind.company || widget.kind == SuggestKind.school)) {
      LogoService.instance.remember(widget.kind, value, entry.logo);
    }

    if (widget.multi) {
      if (_chosen.any((c) => foldText(c) == foldText(value))) {
        _controller.clear();
        _refresh();
        _emit();
        return;
      }
      if (!_fits(value)) return;
      setState(() => _chosen.add(value));
      _controller.clear();
      _focus.requestFocus();
      _refresh();
      _emit();
    } else {
      _controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
      setState(() => _open = false);
      _focus.unfocus();
      _emit();
    }
  }

  void _pickPlace(PlaceResult p) {
    _pick(SuggestEntry(p.name, p.detail, p.full, flag: flagEmoji(p.countryCode)));
  }

  void _removeChip(String value) {
    setState(() => _chosen.remove(value));
    _refresh();
    _emit();
  }

  void _submit(String text) {
    final typed = text.trim();
    if (typed.isEmpty) {
      _focus.unfocus();
      return;
    }
    final key = foldText(typed);
    for (final e in _results) {
      if (foldText(e.title) == key || foldText(e.value) == key) {
        _pick(e);
        return;
      }
    }
    _pick(SuggestEntry(typed, '', typed, custom: true));
  }

  void _clear() {
    _controller.clear();
    _refresh();
    _emit();
    _focus.requestFocus();
  }

  // ---- building ----

  List<InlineSpan> _titleSpans(String title, String query) {
    const base = TextStyle(fontSize: 16, color: Colors.black);
    const bold = TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.w800);
    final q = foldText(query).trim();
    final f = foldText(title);
    if (q.isEmpty || f.length != title.length) return [TextSpan(text: title, style: base)];

    var at = -1;
    var i = f.indexOf(q);
    while (i >= 0) {
      if (i == 0 || ' -./&(,:+'.contains(f[i - 1])) {
        at = i;
        break;
      }
      i = f.indexOf(q, i + 1);
    }
    if (at < 0) at = f.indexOf(q);
    if (at < 0) return [TextSpan(text: title, style: base)];

    return [
      TextSpan(text: title.substring(0, at), style: base),
      TextSpan(text: title.substring(at, at + q.length), style: bold),
      TextSpan(text: title.substring(at + q.length), style: base),
    ];
  }

  Widget _leading(SuggestEntry? e, IconData icon, Color iconColor, Color circle) {
    final kind = widget.kind;
    if (e != null && (kind == SuggestKind.company || kind == SuggestKind.school)) {
      return LogoAvatar(kind: kind, name: e.title, size: 40, knownUrl: e.logo);
    }
    if (e != null && e.flag.isNotEmpty) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: circle, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(e.flag, style: const TextStyle(fontSize: 22)),
      );
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: circle, shape: BoxShape.circle),
      child: Icon(icon, size: 20, color: iconColor),
    );
  }

  Widget _tile({
    SuggestEntry? entry,
    required IconData icon,
    required List<InlineSpan> title,
    String subtitle = '',
    Color iconColor = Colors.black,
    Color circle = _fill,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            _leading(entry, icon, iconColor, circle),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(children: title),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: _grey),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _panel() {
    final query = _controller.text;
    final typed = query.trim();
    final rows = <Widget>[];

    if (typed.isEmpty) {
      rows.add(Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 2),
        child: Text(
          _service.hasRecent(widget.kind) ? 'Recent and popular' : 'Popular',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _grey),
        ),
      ));
    } else {
      rows.add(const SizedBox(height: 8));
    }

    for (final e in _results) {
      rows.add(_tile(
        entry: e,
        icon: widget.kind.icon,
        title: _titleSpans(e.title, query),
        subtitle: e.subtitle,
        trailing: widget.multi ? const Icon(LucideIcons.plus, size: 20, color: _grey) : null,
        onTap: () => _pick(e),
      ));
    }

    if (typed.isNotEmpty && !_service.hasExact(widget.kind, typed, _results)) {
      rows.add(_tile(
        icon: LucideIcons.circlePlus,
        iconColor: _brandBlue,
        circle: _chipFill,
        title: [
          TextSpan(
            text: 'Add \u201c$typed\u201d',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: _brandBlue),
          ),
        ],
        subtitle: _results.isEmpty ? 'Not in the list yet. Save it as typed' : 'Save it as typed',
        onTap: () => _submit(typed),
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  Widget _chips(double maxWidth) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in _chosen)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 7, 8, 7),
                decoration: BoxDecoration(
                  color: _chipFill,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        c,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600, color: _brandBlue),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _removeChip(c),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(LucideIcons.x, size: 16, color: _brandBlue),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showPanel = _open && _focus.hasFocus;
    final chipWidth = MediaQuery.of(context).size.width - 80;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.multi && _chosen.isNotEmpty) _chips(chipWidth),
        if (widget.kind == SuggestKind.place) ...[
          UseLocationButton(onPlace: _pickPlace),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _controller,
          focusNode: _focus,
          cursorColor: Colors.black,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          inputFormatters: [
            LengthLimitingTextInputFormatter(widget.multi ? 60 : widget.maxLength),
          ],
          onChanged: _onTyped,
          onSubmitted: _submit,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: widget.multi && _chosen.isNotEmpty ? 'Add another' : widget.kind.hint,
            filled: true,
            fillColor: _fill,
            counterText: '',
            prefixIcon: const Icon(LucideIcons.search, size: 20, color: _grey),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(LucideIcons.x, size: 18, color: _grey),
                    onPressed: _clear,
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, right: 14),
          child: Row(
            children: [
              Expanded(
                child: widget.errorText == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          widget.errorText!,
                          style: const TextStyle(fontSize: 13, color: Color(0xFFD93025)),
                        ),
                      ),
              ),
              Text('$_length/${widget.maxLength}',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF65676B))),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: showPanel
              ? _panel()
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}



