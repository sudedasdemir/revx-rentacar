import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_app/colors.dart';

class BookingCalendar extends StatelessWidget {
  final DateTime firstDate;
  final DateTime lastDate;
  final List<DateTime> bookedDates;
  final Function(DateTime) onDateSelected;
  final DateTime? selectedDate;

  const BookingCalendar({
    Key? key,
    required this.firstDate,
    required this.lastDate,
    required this.bookedDates,
    required this.onDateSelected,
    this.selectedDate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(theme),
          _buildCalendarGrid(theme),
          _buildLegend(theme),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            DateFormat('MMMM yyyy').format(firstDate),
            style: theme.textTheme.titleLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / 7;
        final daysInMonth =
            DateTimeRange(start: firstDate, end: lastDate).duration.inDays + 1;
        final firstWeekday = firstDate.weekday;
        final numberOfRows = ((daysInMonth + firstWeekday - 1) / 7).ceil();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: List.generate(7, (index) {
                return SizedBox(
                  width: cellWidth,
                  child: Center(
                    child: Text(
                      DateFormat('E').format(DateTime(2024, 1, index + 1))[0],
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }),
            ),
            ...List.generate(numberOfRows, (rowIndex) {
              return Row(
                children: List.generate(7, (colIndex) {
                  final dayIndex = rowIndex * 7 + colIndex - (firstWeekday - 1);
                  if (dayIndex < 0 || dayIndex >= daysInMonth) {
                    return SizedBox(width: cellWidth);
                  }

                  final date = firstDate.add(Duration(days: dayIndex));
                  final isBooked = bookedDates.any(
                    (bookedDate) =>
                        bookedDate.year == date.year &&
                        bookedDate.month == date.month &&
                        bookedDate.day == date.day,
                  );
                  final isSelected =
                      selectedDate != null &&
                      selectedDate!.year == date.year &&
                      selectedDate!.month == date.month &&
                      selectedDate!.day == date.day;

                  return SizedBox(
                    width: cellWidth,
                    height: 40,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Material(
                        color:
                            isBooked
                                ? Colors.red.withOpacity(0.2)
                                : isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: isBooked ? null : () => onDateSelected(date),
                          borderRadius: BorderRadius.circular(8),
                          child: Center(
                            child: Text(
                              '${date.day}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color:
                                    isBooked
                                        ? Colors.red
                                        : isSelected
                                        ? Colors.white
                                        : null,
                                fontWeight: isSelected ? FontWeight.bold : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildLegend(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem(theme, 'Available', Colors.transparent),
          const SizedBox(width: 16),
          _buildLegendItem(theme, 'Booked', Colors.red.withOpacity(0.2)),
          const SizedBox(width: 16),
          _buildLegendItem(theme, 'Selected', AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildLegendItem(ThemeData theme, String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(
              color:
                  color == Colors.transparent
                      ? theme.dividerColor
                      : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
