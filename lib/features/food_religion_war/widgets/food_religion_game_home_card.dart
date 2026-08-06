import 'package:flutter/material.dart';
import 'package:little_star_app/features/food_religion_war/widgets/food_religion_game_screen.dart';

class FoodReligionGameHomeCard extends StatelessWidget {
  const FoodReligionGameHomeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const FoodReligionGameScreen(),
            ),
          );
        },
        child: const ListTile(
          leading: Icon(Icons.emoji_events, color: Colors.deepOrange),
          title: Text('台灣食物宗教戰爭'),
          subtitle: Text('三場淘汰賽，選出你的終極飲食信仰'),
          trailing: Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}
