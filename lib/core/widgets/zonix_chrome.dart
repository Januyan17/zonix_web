import 'package:flutter/material.dart';

import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/theme/zonix_colors.dart';

/// Shared "futuristic" chrome for the Zonix admin: the dark gradient
/// header surface, the blueprint-grid backdrop, holo panels, glow icon
/// tiles, pulse dots, neon switches and pill tab bars. Purely
/// presentational — none of these own any data or actions.
class ZonixChrome {
  ZonixChrome._();

  static const panelRadius = 22.0;

  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF061A2E), ZonixColors.navy, Color(0xFF0E3A5F)],
    stops: [0, 0.55, 1],
  );

  static const accentGradient = LinearGradient(
    colors: [ZonixColors.cyan, ZonixColors.emerald],
  );

  static const iconTileGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [ZonixColors.navy, ZonixColors.chartBlue],
  );
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

/// Dark navy gradient surface with a faint grid, cyan/emerald glow orbs
/// and a neon hairline along the bottom. Used behind app bars and hero
/// banners.
class ZonixHeaderBackground extends StatelessWidget {
  const ZonixHeaderBackground({super.key, this.hairline = true});

  /// Whether to draw the neon line along the bottom edge.
  final bool hairline;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: ZonixChrome.headerGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: CustomPaint(
              painter: ZonixGridPainter(color: Color(0x14FFFFFF), step: 26),
            ),
          ),
          _orb(
            alignment: const Alignment(0.95, -1.6),
            size: 320,
            color: ZonixColors.cyan.withValues(alpha: 0.32),
          ),
          _orb(
            alignment: const Alignment(-0.2, 2.4),
            size: 260,
            color: ZonixColors.emerald.withValues(alpha: 0.22),
          ),
          // Neon hairline along the bottom edge.
          if (hairline)
            const Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: 2,
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0x0038BDF6),
                        ZonixColors.cyan,
                        ZonixColors.emerald,
                        Color(0x0016A34A),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _orb({
    required Alignment alignment,
    required double size,
    required Color color,
  }) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Glass circular action button for the header.
class HeaderGlassButton extends StatelessWidget {
  const HeaderGlassButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.accent = Colors.white,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        shape: CircleBorder(
          side: BorderSide(color: accent.withValues(alpha: 0.45)),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, size: AppDimens.iconXl, color: accent),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Backdrop
// ---------------------------------------------------------------------------

/// Soft brand gradient with a faint blueprint grid, behind the panels.
class ZonixBackdrop extends StatelessWidget {
  const ZonixBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFF2F7FC),
            Color.lerp(const Color(0xFFF6FAFD), ZonixColors.cyan, 0.04)!,
            const Color(0xFFF4FAF6),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: ZonixGridPainter(
                  color: ZonixColors.navy.withValues(alpha: 0.035),
                  step: 32,
                ),
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class ZonixGridPainter extends CustomPainter {
  const ZonixGridPainter({required this.color, required this.step});

  final Color color;
  final double step;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(ZonixGridPainter old) =>
      old.color != color || old.step != step;
}

// ---------------------------------------------------------------------------
// Holo panel
// ---------------------------------------------------------------------------

/// A glass card with a gradient hairline border, a neon accent bar, and an
/// optional module header (gradient icon tile, title, tag, trailing).
///
/// When [flatten] is true, any [Card] directly inside renders without its
/// own background and border, so a section that ships as a single Card
/// becomes the panel body instead of a card-in-a-card.
class HoloPanel extends StatelessWidget {
  const HoloPanel({
    super.key,
    this.child,
    this.icon,
    this.title,
    this.tag,
    this.subtitle,
    this.trailing,
    this.flatten = false,
    this.accent = ZonixColors.cyan,
    this.padding = const EdgeInsets.all(AppDimens.spacing20),
  });

  /// Null for a header-only panel (e.g. a collapsed section).
  final Widget? child;
  final IconData? icon;
  final String? title;

  /// Small uppercase module label shown above the title, e.g. "ACCESS".
  final String? tag;
  final String? subtitle;
  final Widget? trailing;
  final bool flatten;
  final Color accent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(ZonixChrome.panelRadius);

    Widget? body = child;
    if (flatten && body != null) {
      body = Theme(
        data: theme.copyWith(
          cardTheme: theme.cardTheme.copyWith(
            color: Colors.transparent,
            elevation: 0,
            shape: const RoundedRectangleBorder(),
          ),
        ),
        child: body,
      );
    }

    final hasHeader = title != null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.55),
            ZonixColors.navy.withValues(alpha: 0.08),
            ZonixColors.emerald.withValues(alpha: 0.35),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: ZonixColors.navy.withValues(alpha: 0.07),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 18,
            spreadRadius: -4,
          ),
        ],
      ),
      padding: const EdgeInsets.all(1.2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ZonixChrome.panelRadius - 1),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Color.lerp(Colors.white, accent, 0.025)!],
            ),
          ),
          child: Stack(
            children: [
              // Neon accent bar, top-left.
              Positioned(
                top: 0,
                left: 24,
                child: Container(
                  width: 72,
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(3),
                    ),
                    gradient: LinearGradient(
                      colors: [accent, ZonixColors.emerald],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.6),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasHeader)
                    Padding(
                      // A flattened card brings its own 20px padding, which
                      // doubles as the gap under the header.
                      padding: body == null
                          ? const EdgeInsets.all(20)
                          : flatten
                          ? const EdgeInsets.fromLTRB(20, 20, 20, 0)
                          : const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      child: _PanelHeader(
                        icon: icon,
                        title: title!,
                        tag: tag,
                        subtitle: subtitle,
                        trailing: trailing,
                        accent: accent,
                      ),
                    ),
                  if (body == null)
                    const SizedBox.shrink()
                  else if (flatten)
                    body
                  else
                    Padding(
                      padding: hasHeader
                          ? padding.resolve(TextDirection.ltr).copyWith(top: 0)
                          : padding,
                      child: body,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.icon,
    required this.title,
    required this.tag,
    required this.subtitle,
    required this.trailing,
    required this.accent,
  });

  final IconData? icon;
  final String title;
  final String? tag;
  final String? subtitle;
  final Widget? trailing;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          GlowIconTile(icon: icon!, accent: accent),
          const SizedBox(width: AppDimens.spacing14),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tag != null)
                Text(
                  tag!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                    color: Color.lerp(accent, ZonixColors.navy, 0.35),
                  ),
                ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: ZonixColors.navy,
                  letterSpacing: 0.1,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: AppDimens.fontLabel,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Gradient navy tile with a cyan glow, holding a white icon.
class GlowIconTile extends StatelessWidget {
  const GlowIconTile({
    super.key,
    required this.icon,
    this.accent = ZonixColors.cyan,
    this.size = 42,
  });

  final IconData icon;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        gradient: ZonixChrome.iconTileGradient,
        border: Border.all(color: accent.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.48, color: Colors.white),
    );
  }
}

/// A small status dot with an expanding glow ring.
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, required this.color, this.animate = true});

  final Color color;
  final bool animate;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(PulseDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (widget.animate)
                Container(
                  width: 6 + 8 * t,
                  height: 6 + 8 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: 0.45 * (1 - t)),
                  ),
                ),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.7),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Futuristic switch styling for panel headers (same Switch, same
/// value/onChanged — only the colors change).
class NeonSwitch extends StatelessWidget {
  const NeonSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.white,
      activeTrackColor: ZonixColors.emerald,
      inactiveThumbColor: ZonixColors.navy.withValues(alpha: 0.55),
      inactiveTrackColor: ZonixColors.navyContainer.withValues(alpha: 0.6),
      trackOutlineColor: WidgetStatePropertyAll(
        ZonixColors.navy.withValues(alpha: 0.12),
      ),
    );
  }
}

/// Segmented glass pill tab bar for dark surfaces (the header band). Takes
/// ordinary [Tab]s, so badges and listeners inside them keep working.
class ZonixPillTabBar extends StatelessWidget implements PreferredSizeWidget {
  const ZonixPillTabBar({
    super.key,
    required this.tabs,
    this.maxWidth = 420,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 14),
  });

  final List<Widget> tabs;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Size get preferredSize => const Size.fromHeight(62);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            height: 44,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: TabBar(
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              splashBorderRadius: BorderRadius.circular(10),
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [ZonixColors.cyan, Color(0xFF22C3A6)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: ZonixColors.cyan.withValues(alpha: 0.45),
                    blurRadius: 14,
                  ),
                ],
              ),
              labelColor: ZonixColors.navy,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.78),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              tabs: tabs,
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon + label laid out in a row, for [ZonixPillTabBar] tabs.
class ZonixTabLabel extends StatelessWidget {
  const ZonixTabLabel({super.key, required this.icon, required this.label});

  /// Usually an [Icon]; may be wrapped in a [Badge].
  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 36,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTheme.merge(
            data: const IconThemeData(size: AppDimens.iconMd),
            child: icon,
          ),
          const SizedBox(width: AppDimens.spacing8),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

/// A dark, branded app bar for pushed sub-pages (create shop, etc.). Same
/// [AppBar] underneath, so the back button and actions behave as before.
AppBar zonixAppBar({
  required String title,
  String? tag,
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
}) {
  return AppBar(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    foregroundColor: Colors.white,
    elevation: 0,
    scrolledUnderElevation: 0,
    toolbarHeight: tag == null ? kToolbarHeight + 8 : 72,
    iconTheme: const IconThemeData(color: Colors.white),
    actionsIconTheme: const IconThemeData(color: Colors.white),
    flexibleSpace: const ZonixHeaderBackground(),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (tag != null)
          Text(
            tag.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
              color: ZonixColors.cyan.withValues(alpha: 0.95),
            ),
          ),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
    actions: actions,
    bottom: bottom,
  );
}
