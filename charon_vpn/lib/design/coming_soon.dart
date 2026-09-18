import 'package:flutter/material.dart';

import 'colors.dart';
import 'fonts.dart';
import 'section_header.dart';
import 'unit_plate.dart';

/// Placeholder body for nav destinations that don't have real content yet
/// (Split Tunneling, Devices in Milestone 6.1) — swapped for the real screen
/// when its own sub-milestone lands.
class ComingSoon extends StatelessWidget {
  const ComingSoon({super.key, required this.index, required this.title, required this.milestone, this.desc});

  final String index;
  final String title;
  final String milestone;
  final String? desc;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(index: index, title: title, desc: desc),
          const SizedBox(height: 24),
          UnitPlate(
            child: Text('COMING IN MILESTONE $milestone', style: techLabel(fontSize: 13, color: CharonColors.muted)),
          ),
        ],
      ),
    );
  }
}
