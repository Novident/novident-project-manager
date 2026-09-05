import '../layout/separators/layout_separator.dart';
import '../rule/placeholder/placeholder_rules.dart';

class NovidentConstants {
  const NovidentConstants._();
  static const PlaceholderRules kDefaultPlaceholderRules = PlaceholderRules();
  static final LayoutSeparator kDefaultSeparatorStrategy =
      EmptyLineSeparatorStrategy.instance;

  static const Map<int, String> kMonths = <int, String>{
    1: 'january',
    2: 'february',
    3: 'march',
    4: 'april',
    5: 'may',
    6: 'june',
    7: 'july',
    8: 'august',
    9: 'september',
    10: 'october',
    11: 'november',
    12: 'december',
  };
}
