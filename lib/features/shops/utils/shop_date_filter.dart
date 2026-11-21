import 'package:flutter/material.dart';

import 'package:zonixweb/core/utils/date_format.dart';
import 'package:zonixweb/features/shops/models/shop_stats.dart';
import 'package:zonixweb/features/shops/utils/shop_activity_aggregate.dart';

enum ShopDateFilter { day, week, month, allTime, custom }

/// The date filter picked on the shop detail page, and the date windows
/// each part of the page derives from it.
class ShopDateFilterSelection {
  const ShopDateFilterSelection({
    this.filter = ShopDateFilter.day,
    this.customRange,
  });

  final ShopDateFilter filter;
  final DateTimeRange? customRange;

  /// The chart needs a concrete, bounded window even in "all time" mode
  /// (there's no meaningful daily trend over an unbounded range), so it
  /// falls back to the last 30 days — clearly labeled as such rather than
  /// silently disagreeing with the "all time" totals shown in the tiles.
  (DateTime, DateTime, String) chartWindow() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (filter) {
      case ShopDateFilter.allTime:
        return (
          today.subtract(const Duration(days: 29)),
          today,
          'last 30 days',
        );
      case ShopDateFilter.day:
        return (today.subtract(const Duration(days: 6)), today, 'last 7 days');
      case ShopDateFilter.week:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return (
          DateTime(monday.year, monday.month, monday.day),
          today,
          'this week',
        );
      case ShopDateFilter.month:
        return (DateTime(now.year, now.month, 1), today, 'this month');
      case ShopDateFilter.custom:
        final range = customRange;
        if (range == null) {
          return (
            today.subtract(const Duration(days: 29)),
            today,
            'last 30 days',
          );
        }
        return (
          range.start,
          range.end,
          '${range.start.day}/${range.start.month} - ${range.end.day}/${range.end.month}',
        );
    }
  }

  /// The selected filter's own range, named. Distinct from the chart
  /// window's label: the Day filter totals today while the chart shows the
  /// last 7 days, and a card reading off the totals must not borrow the
  /// chart's wider caption.
  String label() {
    switch (filter) {
      case ShopDateFilter.day:
        return 'today';
      case ShopDateFilter.week:
        return 'this week';
      case ShopDateFilter.month:
        return 'this month';
      case ShopDateFilter.allTime:
        return 'all time';
      case ShopDateFilter.custom:
        final range = customRange;
        if (range == null) return 'all time';
        return '${formatShortDate(range.start)} - ${formatShortDate(range.end)}';
    }
  }

  /// The range the stat tiles total over; null means all time.
  StatsDateRange? range() {
    final now = DateTime.now();
    switch (filter) {
      case ShopDateFilter.allTime:
        return null;
      case ShopDateFilter.day:
        final today = DateTime(now.year, now.month, now.day);
        return StatsDateRange(start: today, end: today);
      case ShopDateFilter.week:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return StatsDateRange(
          start: DateTime(monday.year, monday.month, monday.day),
          end: DateTime(now.year, now.month, now.day),
        );
      case ShopDateFilter.month:
        return StatsDateRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day),
        );
      case ShopDateFilter.custom:
        final range = customRange;
        if (range == null) return null;
        return StatsDateRange(start: range.start, end: range.end);
    }
  }

  /// The narrowest day range that still answers everything on the page.
  /// The tiles and the chart don't always ask the same question — the Day
  /// filter totals today but charts the last 7 days — so the fetch has to
  /// span both. All time is unbounded on purpose: there's no window that
  /// answers it.
  ({DateTime? from, DateTime? to}) activityWindow() {
    final range = this.range();
    if (range == null) return (from: null, to: null);
    final (chartStart, chartEnd, _) = chartWindow();

    var from = range.start.isBefore(chartStart) ? range.start : chartStart;
    // The tiles also compare against the period immediately before the
    // selected one, which is only honest if those documents were actually
    // fetched — an unfetched previous period reads as zero, and every tile
    // would claim record growth.
    final previous = precedingRange(range);
    if (previous != null && previous.start.isBefore(from)) {
      from = previous.start;
    }

    return (from: from, to: range.end.isAfter(chartEnd) ? range.end : chartEnd);
  }
}
