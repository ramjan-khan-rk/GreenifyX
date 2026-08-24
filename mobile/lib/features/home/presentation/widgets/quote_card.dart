import 'package:flutter/material.dart';

import '../../../../core/widgets/app_card.dart';
import '../../../../core/theme/app_text_styles.dart';

class QuoteCard extends StatelessWidget {
  const QuoteCard({super.key});

  @override
  Widget build(BuildContext context) {

    return const AppCard(

      child: Text(
        "💚 Every small act of kindness makes the world a little greener.",
        textAlign: TextAlign.center,
      ),

    );

  }
}