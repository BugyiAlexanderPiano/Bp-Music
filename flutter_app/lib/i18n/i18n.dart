// lib/i18n/i18n.dart — többnyelvű felület
//
// A forrásnyelv a magyar: a kódban tr('Magyar szöveg {0}', [érték]) áll, a fordítási
// táblák kulcsa maga a magyar szöveg. Hiányzó fordításnál angol, végül magyar a tartalék.
import 'lang/bg.dart';
import 'lang/cs.dart';
import 'lang/de.dart';
import 'lang/el.dart';
import 'lang/en.dart';
import 'lang/es.dart';
import 'lang/fr.dart';
import 'lang/hr.dart';
import 'lang/it.dart';
import 'lang/nl.dart';
import 'lang/pl.dart';
import 'lang/pt.dart';
import 'lang/ro.dart';
import 'lang/ru.dart';
import 'lang/sk.dart';
import 'lang/sl.dart';
import 'lang/sr.dart';
import 'lang/tr.dart';
import 'lang/uk.dart';

/// Nyelvkód → a nyelv saját neve (a választóban így jelenik meg)
const languages = <String, String>{
  'hu': 'Magyar',
  'en': 'English',
  'de': 'Deutsch',
  'fr': 'Français',
  'es': 'Español',
  'it': 'Italiano',
  'pt': 'Português',
  'nl': 'Nederlands',
  'pl': 'Polski',
  'cs': 'Čeština',
  'sk': 'Slovenčina',
  'ro': 'Română',
  'hr': 'Hrvatski',
  'sr': 'Srpski',
  'sl': 'Slovenščina',
  'ru': 'Русский',
  'uk': 'Українська',
  'bg': 'Български',
  'el': 'Ελληνικά',
  'tr': 'Türkçe',
};

const _tables = <String, Map<String, String>>{
  'en': en, 'de': de, 'fr': fr, 'es': es, 'it': it, 'pt': pt, 'nl': nl, 'pl': pl, 'cs': cs, 'sk': sk,
  'ro': ro, 'hr': hr, 'sr': sr, 'sl': sl, 'ru': ru, 'uk': uk, 'bg': bg, 'el': el, 'tr': trTable,
};

class I18n {
  static String lang = 'hu';

  /// A rendszer nyelvéből a legközelebbi támogatott nyelv
  static String bestFor(String? systemLang) {
    final l = (systemLang ?? 'hu').toLowerCase();
    return languages.containsKey(l) ? l : 'en';
  }
}

/// Fordítás: a magyar forrásszöveg alapján; {0}, {1}… helyére az args értékei kerülnek
String tr(String hu, [List<Object?> args = const []]) {
  var s = I18n.lang == 'hu' ? hu : (_tables[I18n.lang]?[hu] ?? en[hu] ?? hu);
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i]}');
  }
  return s;
}
