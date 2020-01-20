// Copyright 2020 Ramon Millsteed. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_clock_helper/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart';

class _ClockTheme {
  final Color background;
  final Color coolBackground;
  final Color warmBackground;
  final Color foreground;
  final Color coolForeground;
  final Color warmForeground;

  const _ClockTheme({
    @required this.background,
    @required this.coolBackground,
    @required this.warmBackground,
    @required this.foreground,
    @required this.coolForeground,
    @required this.warmForeground,
  });
}

class _ClockMath {
  static double calculateAngle(double value, double max) {
    return value / max * 2 * math.pi;
  }

  static Offset vectorToOffset(double magnitude, double angle) {
    return Offset(math.cos(angle), math.sin(angle)) * magnitude;
  }
}

const _ClockTheme _LIGHT_THEME = _ClockTheme(
  background: const Color(0xFFF0F0F0),
  coolBackground: const Color(0xFFE0E0F0),
  warmBackground: const Color(0xFFF0E0E0),
  foreground: const Color(0xFF404040),
  coolForeground: const Color(0xFF404050),
  warmForeground: const Color(0xFF504040),
);

const _ClockTheme _DARK_THEME = _ClockTheme(
  background: const Color(0xFF303030),
  coolBackground: const Color(0xFF303038),
  warmBackground: const Color(0xFF383030),
  foreground: const Color(0xFF808080),
  coolForeground: const Color(0xFF707080),
  warmForeground: const Color(0xFF807070),
);

const int _REFRESH_RATE_SECONDS = 1;

const Duration _REFRESH_RATE_DURATION = const Duration(
  seconds: _REFRESH_RATE_SECONDS,
);

class DymaxionClock extends StatefulWidget {
  const DymaxionClock(this.model);

  final ClockModel model;

  @override
  _DymaxionClockState createState() => _DymaxionClockState();
}

class _DymaxionClockState extends State<DymaxionClock> {
  Timer _timer;

  DateTime _dateTime = DateTime.now();

  bool _is24HourFormat = true;

  double _low = 1;
  double _temperature = 1;
  double _high = 1;

  @override
  void initState() {
    super.initState();
    widget.model.addListener(_updateModel);
    _updateTime();
    _updateModel();
  }

  @override
  void didUpdateWidget(DymaxionClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.model != oldWidget.model) {
      oldWidget.model.removeListener(_updateModel);
      widget.model.addListener(_updateModel);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.model.removeListener(_updateModel);
    widget.model.dispose();
    super.dispose();
  }

  void _updateModel() {
    setState(() {
      _is24HourFormat = widget.model.is24HourFormat;
      _low = widget.model.low;
      _temperature = widget.model.temperature;
      _high = widget.model.high;
    });
  }

  void _updateTime() {
    setState(() {
      _dateTime = DateTime.now();
      _timer = Timer(
        _REFRESH_RATE_DURATION - Duration(milliseconds: _dateTime.millisecond),
        _updateTime,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final String time = DateFormat.Hms().format(_dateTime);

    final double range = _high - _low;

    double coolIntensity = (0.5 - (_temperature - _low) / range) / 0.5;
    if (coolIntensity < 0) coolIntensity = 0;
    if (coolIntensity > 1) coolIntensity = 1;

    double warmIntensity = (0.5 - (_high - _temperature) / range) / 0.5;
    if (warmIntensity < 0) warmIntensity = 0;
    if (warmIntensity > 1) warmIntensity = 1;

    final _ClockTheme theme = Theme.of(context).brightness == Brightness.light
        ? _LIGHT_THEME
        : _DARK_THEME;
    final Color background = coolIntensity > warmIntensity
        ? Color.lerp(theme.background, theme.coolBackground, coolIntensity)
        : Color.lerp(theme.background, theme.warmBackground, warmIntensity);
    final Color foreground = coolIntensity > warmIntensity
        ? Color.lerp(theme.foreground, theme.coolForeground, coolIntensity)
        : Color.lerp(theme.foreground, theme.warmForeground, warmIntensity);

    return Semantics.fromProperties(
      properties: SemanticsProperties(
        label: 'Clock with time $time',
        value: time,
      ),
      child: Stack(
        children: <Widget>[
          _buildBackground(background),
          _buildContent(background, foreground),
        ],
      ),
    );
  }

  Widget _buildBackground(Color color) {
    return AnimatedContainer(
      duration: _REFRESH_RATE_DURATION,
      color: color,
    );
  }

  Widget _buildContent(Color background, Color foreground) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _buildDate(foreground),
        ),
        Expanded(
          flex: 2,
          child: _buildClock(background, foreground),
        ),
        Expanded(
          child: _buildTime(foreground),
        ),
      ],
    );
  }

  Widget _buildDate(Color color) {
    return _buildDateTimeLabel(color, 'MMMd');
  }

  Widget _buildTime(Color color) {
    return _buildDateTimeLabel(color, '${_is24HourFormat ? 'H' : 'h'}:mm');
  }

  Widget _buildDateTimeLabel(Color color, String format) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Center(
          child: Text(
            DateFormat(format).format(_dateTime),
            style: TextStyle(
              fontWeight: FontWeight.w300,
              fontSize: constraints.maxWidth / 5,
              color: color,
            ),
          ),
        );
      },
    );
  }

  Widget _buildClock(Color background, Color foreground) {
    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            double radius = constraints.maxWidth / 2;
            double seconds = _dateTime.second.toDouble();
            double minutes = _dateTime.minute + seconds / 60;
            double hours = _dateTime.hour + minutes / 60;
            double shadowAngle = _ClockMath.calculateAngle(seconds - 15, 60);
            double minuteAngle = _ClockMath.calculateAngle(minutes, 60);
            double hourAngle = _ClockMath.calculateAngle(hours, 12);
            return Stack(
              children: <Widget>[
                _buildClockShadow(radius, shadowAngle),
                _buildClockBackground(background, radius, shadowAngle),
                _MinuteHand(
                  color: foreground,
                  radius: radius,
                  handAngle: minuteAngle,
                  shadowAngle: shadowAngle,
                ),
                _HourHand(
                  color: foreground,
                  radius: radius,
                  handAngle: hourAngle,
                  shadowAngle: shadowAngle,
                ),
                _buildClockBorder(foreground, radius),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildClockShadow(double radius, double angle) {
    return AnimatedContainer(
      duration: _REFRESH_RATE_DURATION,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: radius / 5,
            offset: _ClockMath.vectorToOffset(radius / 8, angle),
          ),
        ],
      ),
    );
  }

  Widget _buildClockBackground(Color color, double radius, double angle) {
    return ClipOval(
      child: AnimatedContainer(
        duration: _REFRESH_RATE_DURATION,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color.lerp(color, Colors.black, 3 / 3),
              blurRadius: 0,
              offset: Offset.zero,
            ),
            BoxShadow(
              color: Color.lerp(color, Colors.black, 2 / 3),
              blurRadius: radius / 6,
              offset: _ClockMath.vectorToOffset(radius / 12, angle),
            ),
            BoxShadow(
              color: Color.lerp(color, Colors.black, 1 / 3),
              blurRadius: radius / 4,
              offset: _ClockMath.vectorToOffset(radius / 8, angle),
            ),
            BoxShadow(
              color: Color.lerp(color, Colors.black, 0 / 3),
              blurRadius: radius / 8,
              offset: _ClockMath.vectorToOffset(radius / 4, angle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClockBorder(Color color, double radius) {
    return AnimatedContainer(
      duration: _REFRESH_RATE_DURATION,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: radius / 10),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

abstract class _Hand extends StatelessWidget {
  final Color color;
  final double radius;
  final double handAngle;
  final double shadowAngle;
  final double lengthRatio;

  const _Hand({
    @required this.color,
    @required this.radius,
    @required this.handAngle,
    @required this.shadowAngle,
    @required this.lengthRatio,
  });

  Widget _buildTransform({@required Widget child}) {
    return Transform.rotate(
      angle: handAngle,
      child: ClipOval(
        child: Container(
          alignment: Alignment.topCenter,
          child: Container(
            height: radius,
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildBase(BoxDecoration decoration) {
    return Transform.rotate(
      angle: _ClockMath.calculateAngle(45, 360),
      child: AnimatedContainer(
        duration: _REFRESH_RATE_DURATION,
        width: radius / 8,
        height: radius / 8,
        decoration: decoration,
      ),
    );
  }

  Widget _buildLine(BoxDecoration decoration) {
    return AnimatedContainer(
      duration: _REFRESH_RATE_DURATION,
      width: radius / 25,
      height: radius * lengthRatio,
      decoration: decoration,
    );
  }

  BoxDecoration _buildShadowDecoration() {
    int n = 30;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: <BoxShadow>[
        for (double i = 0; i < n; i++)
          BoxShadow(
            color: Colors.black.withOpacity(0.15 * ((n - i) / n)),
            blurRadius: i * radius / 250,
            spreadRadius: -i * radius / 1000,
            offset: _ClockMath.vectorToOffset(
              i * radius / 50,
              shadowAngle - handAngle,
            ),
          ),
      ],
    );
  }

  BoxDecoration _buildFillDecoration(bool rounded) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(rounded ? radius : 0),
    );
  }
}

class _MinuteHand extends _Hand {
  static const double _MINUTE_HAND_LENGTH_RATIO = 0.6;

  _MinuteHand({
    @required Color color,
    @required double radius,
    @required double handAngle,
    @required double shadowAngle,
  }) : super(
          color: color,
          radius: radius,
          handAngle: handAngle,
          shadowAngle: shadowAngle,
          lengthRatio: _MINUTE_HAND_LENGTH_RATIO,
        );

  @override
  Widget build(BuildContext context) {
    return _buildTransform(
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          _buildCircle(_buildCircleShadowDecoration()),
          _buildLine(_buildShadowDecoration()),
          _buildCircle(_buildFillDecoration(true)),
          _buildBase(_buildFillDecoration(false)),
          _buildLine(_buildFillDecoration(true)),
        ],
      ),
    );
  }

  Widget _buildCircle(BoxDecoration decoration) {
    return Transform.translate(
      offset: Offset(0, radius / 9.4),
      child: AnimatedContainer(
        duration: _REFRESH_RATE_DURATION,
        width: radius / 4.7,
        height: radius / 4.7,
        decoration: decoration,
      ),
    );
  }

  BoxDecoration _buildCircleShadowDecoration() {
    int n = 20;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: <BoxShadow>[
        for (double i = 0; i < n; i++)
          BoxShadow(
            color: Colors.black.withOpacity(0.05 * ((n - i) / n)),
            blurRadius: i * radius / 500,
            spreadRadius: -i * radius / 1000,
            offset: _ClockMath.vectorToOffset(
              i * radius / 50,
              shadowAngle - handAngle,
            ),
          ),
      ],
    );
  }
}

class _HourHand extends _Hand {
  static const double _HOUR_HAND_LENGTH_RATIO = 0.4;

  _HourHand({
    @required Color color,
    @required double radius,
    @required double handAngle,
    @required double shadowAngle,
  }) : super(
          color: color,
          radius: radius,
          handAngle: handAngle,
          shadowAngle: shadowAngle,
          lengthRatio: _HOUR_HAND_LENGTH_RATIO,
        );

  @override
  Widget build(BuildContext context) {
    return _buildTransform(
      child: Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[
          _buildLine(_buildShadowDecoration()),
          _buildBase(_buildFillDecoration(false)),
          _buildLine(_buildFillDecoration(true)),
        ],
      ),
    );
  }
}
