import 'package:flutter/material.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_game_session.dart';
import 'package:little_star_app/features/food_religion_war/services/food_religion_judgment_service.dart';
import 'package:little_star_app/features/food_religion_war/widgets/food_religion_game_screen.dart';

class FoodReligionGameHomeCard extends StatelessWidget {
  const FoodReligionGameHomeCard({
    super.key,
    this.judgmentServiceFactory,
    this.randomizer,
  });

  final FoodReligionJudgmentService Function()? judgmentServiceFactory;
  final FoodReligionGameRandomizer? randomizer;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder:
                  (_) => FoodReligionGameScreen(
                    judgmentServiceFactory: judgmentServiceFactory,
                    randomizer: randomizer,
                  ),
            ),
          );
        },
        child: const ListTile(
          leading: Icon(Icons.restaurant_menu, color: Colors.deepOrange),
          title: Text('台灣食物宗教戰爭'),
          subtitle: Text('四次飲食抉擇，一次辯護抽籤'),
          trailing: Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}
