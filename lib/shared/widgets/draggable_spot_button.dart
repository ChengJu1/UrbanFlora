import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/router/app_router.dart';

/// "Spot" button that you can drag around. Fling it to either side and it
/// hides as a tiny chevron tab — tap the tab to get it back.
class DraggableSpotButton extends StatefulWidget {
  const DraggableSpotButton({super.key});

  @override
  State<DraggableSpotButton> createState() => _DraggableSpotButtonState();
}

class _DraggableSpotButtonState extends State<DraggableSpotButton> {
  static const double _fabWidth = 116;
  static const double _fabHeight = 56;
  static const double _dotSize = 40;
  static const double _flingThreshold = 700; // px / s
  static const double _dragSlop = 6; // px before pan kicks in

  static const String _kPosX = 'spot_btn_pos_x';
  static const String _kPosY = 'spot_btn_pos_y';
  static const String _kHidden = 'spot_btn_hidden';
  static const String _kStickRight = 'spot_btn_stick_right';

  Offset? _pos; // top-left of the FAB
  bool _hidden = false;
  bool _stickRight = true;
  bool _restored = false;

  // so a drag-then-release doesn't also count as a tap
  bool _dragged = false;
  Offset _dragStart = Offset.zero;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      final dx = prefs.getDouble(_kPosX);
      final dy = prefs.getDouble(_kPosY);
      if (dx != null && dy != null) _pos = Offset(dx, dy);
      _hidden = prefs.getBool(_kHidden) ?? false;
      _stickRight = prefs.getBool(_kStickRight) ?? true;
      _restored = true;
    });
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (_pos != null) {
      await prefs.setDouble(_kPosX, _pos!.dx);
      await prefs.setDouble(_kPosY, _pos!.dy);
    }
    await prefs.setBool(_kHidden, _hidden);
    await prefs.setBool(_kStickRight, _stickRight);
  }

  Offset _defaultPos(BoxConstraints c) => Offset(
        c.maxWidth - _fabWidth - 16,
        c.maxHeight - _fabHeight - 16,
      );

  @override
  Widget build(BuildContext context) {
    if (!_restored) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, c) {
        return _hidden
            ? _buildPeekTab(context, c)
            : _buildDraggableFab(context, c);
      },
    );
  }

  Widget _buildPeekTab(BuildContext context, BoxConstraints c) {
    final scheme = Theme.of(context).colorScheme;
    final defaultPos = _defaultPos(c);
    final centerY = (_pos?.dy ?? defaultPos.dy) + _fabHeight / 2;
    final top = (centerY - _dotSize / 2)
        .clamp(8.0, c.maxHeight - _dotSize - 8.0);
    final left =
        _stickRight ? c.maxWidth - _dotSize * 0.7 : -_dotSize * 0.3;

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          child: Material(
            color: scheme.primary,
            elevation: 4,
            borderRadius: BorderRadius.circular(_dotSize),
            child: InkWell(
              borderRadius: BorderRadius.circular(_dotSize),
              onTap: () async {
                setState(() => _hidden = false);
                await _persist();
              },
              child: SizedBox(
                width: _dotSize,
                height: _dotSize,
                child: Icon(
                  _stickRight ? Icons.chevron_left : Icons.chevron_right,
                  color: scheme.onPrimary,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDraggableFab(BuildContext context, BoxConstraints c) {
    // clamp again in case the screen got smaller (rotation, etc)
    final pos = _pos == null
        ? _defaultPos(c)
        : Offset(
            _pos!.dx.clamp(0.0, (c.maxWidth - _fabWidth).clamp(0.0, double.infinity)),
            _pos!.dy.clamp(0.0, (c.maxHeight - _fabHeight).clamp(0.0, double.infinity)),
          );
    return Stack(
      children: [
        AnimatedPositioned(
          duration: _dragged
              ? Duration.zero
              : const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          left: pos.dx,
          top: pos.dy,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: (d) {
              _dragged = false;
              _dragStart = d.localPosition;
            },
            onPanUpdate: (d) {
              if (!_dragged &&
                  (d.localPosition - _dragStart).distance < _dragSlop) {
                return;
              }
              _dragged = true;
              setState(() {
                _pos = Offset(
                  (pos.dx + d.delta.dx)
                      .clamp(0.0, c.maxWidth - _fabWidth),
                  (pos.dy + d.delta.dy)
                      .clamp(0.0, c.maxHeight - _fabHeight),
                );
              });
            },
            onPanEnd: (d) async {
              final v = d.velocity.pixelsPerSecond;
              if (v.distance > _flingThreshold) {
                setState(() {
                  _hidden = true;
                  _stickRight = v.dx >= 0;
                });
              }
              await _persist();
            },
            onTap: () {
              if (_dragged) return;
              context.push(AppRoutes.capture);
            },
            child: _SpotPill(),
          ),
        ),
      ],
    );
  }
}

class _SpotPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary,
      elevation: 6,
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        width: _DraggableSpotButtonState._fabWidth,
        height: _DraggableSpotButtonState._fabHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_rounded, color: scheme.onPrimary, size: 22),
            const SizedBox(width: 8),
            Text(
              'Spot',
              style: TextStyle(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
