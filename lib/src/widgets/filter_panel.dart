import 'package:flutter/material.dart';

import '../peer_filter.dart';

/// Collapsible filter panel for narrowing nearby peer discovery.
///
/// Controlled widget — the parent owns [filter] and [expanded] state.
/// [onChanged] receives updated filters; [onExpandedChanged] receives
/// expand/collapse requests.
class FilterPanel extends StatefulWidget {
  const FilterPanel({
    super.key,
    required this.filter,
    required this.expanded,
    required this.onExpandedChanged,
    required this.onChanged,
  });

  final PeerFilter filter;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final ValueChanged<PeerFilter> onChanged;

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  late bool _ageEnabled;
  late bool _heightEnabled;

  @override
  void initState() {
    super.initState();
    _ageEnabled = _filterHasActiveAge(widget.filter);
    _heightEnabled = _filterHasActiveHeight(widget.filter);
  }

  @override
  void didUpdateWidget(FilterPanel old) {
    super.didUpdateWidget(old);
    if (!_filterHasActiveAge(widget.filter)) _ageEnabled = false;
    if (!_filterHasActiveHeight(widget.filter)) _heightEnabled = false;
  }

  static bool _filterHasActiveAge(PeerFilter f) =>
      f.ageMin != kAgeMin || f.ageMax != kAgeMax;

  static bool _filterHasActiveHeight(PeerFilter f) =>
      f.heightMin != kHeightMin || f.heightMax != kHeightMax;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          filter: widget.filter,
          expanded: widget.expanded,
          onTap: () => widget.onExpandedChanged(!widget.expanded),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: widget.expanded
              ? _Body(
                  filter: widget.filter,
                  ageEnabled: _ageEnabled,
                  heightEnabled: _heightEnabled,
                  onAgeEnabledChanged: (v) {
                    setState(() => _ageEnabled = v);
                    if (!v) {
                      widget.onChanged(
                        widget.filter.copyWith(
                          ageMin: kAgeMin,
                          ageMax: kAgeMax,
                        ),
                      );
                    }
                  },
                  onHeightEnabledChanged: (v) {
                    setState(() => _heightEnabled = v);
                    if (!v) {
                      widget.onChanged(
                        widget.filter.copyWith(
                          heightMin: kHeightMin,
                          heightMax: kHeightMax,
                        ),
                      );
                    }
                  },
                  onChanged: widget.onChanged,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({
    required this.filter,
    required this.expanded,
    required this.onTap,
  });

  final PeerFilter filter;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('filter-panel-header'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.tune, size: 18),
            const SizedBox(width: 8),
            const Text('Filter'),
            if (filter.isActive) ...[
              const SizedBox(width: 6),
              _Badge(count: filter.activeCount),
            ],
            const Spacer(),
            Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 18),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('filter-active-count'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _Body extends StatelessWidget {
  const _Body({
    required this.filter,
    required this.ageEnabled,
    required this.heightEnabled,
    required this.onAgeEnabledChanged,
    required this.onHeightEnabledChanged,
    required this.onChanged,
  });

  final PeerFilter filter;
  final bool ageEnabled;
  final bool heightEnabled;
  final ValueChanged<bool> onAgeEnabledChanged;
  final ValueChanged<bool> onHeightEnabledChanged;
  final ValueChanged<PeerFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 320),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 1),
              const SizedBox(height: 4),

              // Gender
              _MultiSection(
                label: 'Gender',
                options: kGenderOptions,
                selected: filter.genders,
                keyPrefix: 'filter-checkbox-gender',
                onTap: (v) => onChanged(filter.toggleGender(v)),
              ),

              // Body Shape
              _MultiSection(
                label: 'Body Shape',
                options: kBodyShapeOptions,
                selected: filter.bodyShapes,
                keyPrefix: 'filter-checkbox-bodyShape',
                onTap: (v) => onChanged(filter.toggleBodyShape(v)),
              ),

              // Hair Colour
              _MultiSection(
                label: 'Hair Colour',
                options: kHairColourOptions,
                selected: filter.hairColours,
                keyPrefix: 'filter-checkbox-hairColour',
                onTap: (v) => onChanged(filter.toggleHairColour(v)),
              ),

              const SizedBox(height: 4),

              // Age range
              _RangeSection(
                label: ageEnabled
                    ? 'Age  ${filter.ageMin}–${filter.ageMax}'
                    : 'Age',
                toggleKey: const Key('filter-toggle-age'),
                enabled: ageEnabled,
                onEnabledChanged: onAgeEnabledChanged,
                sliderChild: RangeSlider(
                  key: const Key('filter-slider-age'),
                  values: RangeValues(
                    filter.ageMin.toDouble(),
                    filter.ageMax.toDouble(),
                  ),
                  min: kAgeMin.toDouble(),
                  max: kAgeMax.toDouble(),
                  divisions: kAgeMax - kAgeMin,
                  labels: RangeLabels(
                    filter.ageMin.toString(),
                    filter.ageMax.toString(),
                  ),
                  onChanged: (v) => onChanged(
                    filter.copyWith(
                      ageMin: v.start.round(),
                      ageMax: v.end.round(),
                    ),
                  ),
                ),
              ),

              // Height range
              _RangeSection(
                label: heightEnabled
                    ? 'Height  ${filter.heightMin}–${filter.heightMax} cm'
                    : 'Height',
                toggleKey: const Key('filter-toggle-height'),
                enabled: heightEnabled,
                onEnabledChanged: onHeightEnabledChanged,
                sliderChild: RangeSlider(
                  key: const Key('filter-slider-height'),
                  values: RangeValues(
                    filter.heightMin.toDouble(),
                    filter.heightMax.toDouble(),
                  ),
                  min: kHeightMin.toDouble(),
                  max: kHeightMax.toDouble(),
                  divisions: kHeightMax - kHeightMin,
                  labels: RangeLabels(
                    '${filter.heightMin} cm',
                    '${filter.heightMax} cm',
                  ),
                  onChanged: (v) => onChanged(
                    filter.copyWith(
                      heightMin: v.start.round(),
                      heightMax: v.end.round(),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 4),

              // Clear all
              Center(
                child: TextButton(
                  key: const Key('filter-clear-all'),
                  onPressed: () => onChanged(filter.cleared),
                  child: const Text('Clear all'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _MultiSection — field title + horizontal Wrap of inline checkboxes
// ---------------------------------------------------------------------------

class _MultiSection extends StatelessWidget {
  const _MultiSection({
    required this.label,
    required this.options,
    required this.selected,
    required this.keyPrefix,
    required this.onTap,
  });

  final String label;
  final List<String> options;
  final Set<String> selected;
  final String keyPrefix;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelMedium;
    final optionStyle = Theme.of(context).textTheme.bodySmall;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Field title
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(label, style: labelStyle),
          ),
          // Options — indented, wrap horizontally
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Wrap(
              runSpacing: 0,
              children: [
                for (final option in options)
                  GestureDetector(
                    onTap: () => onTap(option),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          key: Key('$keyPrefix-$option'),
                          value: selected.contains(option),
                          onChanged: (_) => onTap(option),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        Text(option, style: optionStyle),
                        const SizedBox(width: 12),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _RangeSection — tappable field title with rotating chevron + optional slider
// ---------------------------------------------------------------------------

class _RangeSection extends StatelessWidget {
  const _RangeSection({
    required this.label,
    required this.toggleKey,
    required this.enabled,
    required this.onEnabledChanged,
    required this.sliderChild,
  });

  final String label;
  final Key toggleKey;
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final Widget sliderChild;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelMedium;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tappable label + chevron
          InkWell(
            key: toggleKey,
            onTap: () => onEnabledChanged(!enabled),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: labelStyle),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: enabled ? 0.25 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.chevron_right, size: 16),
                  ),
                ],
              ),
            ),
          ),
          // Offstage keeps the RangeSlider's render object (and its internal
          // AnimationController) alive, preventing a crash when a hover event
          // fires on the slider in the same frame it would otherwise be disposed.
          Offstage(
            offstage: !enabled,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: sliderChild,
            ),
          ),
        ],
      ),
    );
  }
}
