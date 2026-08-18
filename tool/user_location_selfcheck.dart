// ponytail: dart run tool/user_location_selfcheck.dart
import '../lib/utils/password.dart';
import '../lib/utils/user_location.dart';

void main() {
  final list = parseUserLocations([
    {
      'id': 'a',
      'title': 'Trabajo',
      'address': 'Av. Principal, Caracas 1030, Venezuela',
      'lat': 10.5,
      'lng': -66.9,
    },
    {
      'id': 'b',
      'alias': 'Casa',
      'address': 'Calle Real, Caracas 1030, Venezuela',
      'lat': 10.48,
      'lng': -66.95,
      'isDefault': true,
    },
  ]);
  final def = pickDefaultLocation(list);
  if (def?.id != 'b') throw StateError('default should be b, got ${def?.id}');
  final label = shortLocationLabel(def, loggedIn: true);
  if (!label.contains('Casa')) {
    throw StateError('label $label');
  }
  if (shortLocationLabel(null, loggedIn: false) != 'Elige tu ubicación') {
    throw StateError('guest label');
  }
  final generic = UserLocation(
    id: 'g',
    title: 'Mi ubicación',
    address: 'Plaza Venezuela, Caracas 1050',
  );
  final genericLabel = shortLocationLabel(generic, loggedIn: true);
  if (genericLabel.contains('Mi ubicación')) {
    throw StateError('generic title leaked: $genericLabel');
  }
  if (checkPwd('Abcdef1!') != null) throw StateError('valid pwd rejected');
  if (checkPwd('short') == null) throw StateError('short pwd accepted');
  // ignore: avoid_print
  print('user_location_selfcheck ok');
}
