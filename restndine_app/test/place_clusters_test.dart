import 'package:flutter_test/flutter_test.dart';
import 'package:restndine_app/models/place_model.dart';
import 'package:restndine_app/screens/map/place_clusters.dart';

PlaceModel _place(int id, double lat, double lng) => PlaceModel.fromJson({
      'id': id,
      'name': 'P$id',
      'latitude': lat,
      'longitude': lng,
      'categories': const [],
    });

void main() {
  // Ba quán sát nhau ở Quận 1, một quán ở Thủ Đức (~12 km), hai quán trùng toạ độ, một quán thiếu toạ độ
  final places = [
    _place(1, 10.7770, 106.7010),
    _place(2, 10.7772, 106.7012),
    _place(3, 10.7766, 106.7005),
    _place(4, 10.8700, 106.8030),
    _place(5, 10.7800, 106.6900),
    _place(6, 10.7800, 106.6900),
    _place(7, 0, 0),
  ];

  List<List<int>> groups(List<PlaceCluster> clusters) =>
      [for (final c in clusters) c.places.map((p) => p.id).toList()]..sort((a, b) => a.first - b.first);

  test('zoom xa: các quán gần nhau gộp một nhóm, bỏ qua địa điểm thiếu toạ độ', () {
    final c = PlaceClusterer(places);
    final ids = groups(c.clustersAt(11));
    expect(ids.expand((g) => g), unorderedEquals([1, 2, 3, 4, 5, 6]));
    expect(ids.firstWhere((g) => g.contains(1)), containsAll([1, 2, 3]));
    expect(ids.firstWhere((g) => g.contains(4)), [4]);
  });

  test('zoom gần: tách hết, chỉ còn gom các địa điểm trùng toạ độ', () {
    final clusters = PlaceClusterer(places).clustersAt(18);
    expect(groups(clusters), [
      [1],
      [2],
      [3],
      [4],
      [5, 6],
    ]);
    final same = clusters.firstWhere((c) => c.count == 2);
    expect(same.isSameSpot, isTrue);
    expect(same.point.latitude, closeTo(10.78, 1e-9));
  });

  test('trọng tâm và khung bao của nhóm', () {
    final cluster = PlaceClusterer(places).clustersAt(11).firstWhere((c) => c.places.any((p) => p.id == 1));
    expect(cluster.isSameSpot, isFalse);
    expect(cluster.bounds.contains(cluster.point), isTrue);
    expect(cluster.bounds.north, greaterThanOrEqualTo(10.7772));
  });

  test('kết quả mỗi mức zoom được nhớ lại', () {
    final c = PlaceClusterer(places);
    expect(identical(c.clustersAt(13), c.clustersAt(13)), isTrue);
  });

  test('hai quán sát nhau nhưng nằm hai bên đường kẻ ô vẫn gộp một nhóm', () {
    // Ở zoom 14 (ô 64 px) kinh độ 106.69921875 là đúng một đường kẻ ô; hai quán cách nhau ~7 px
    const edge = 106.69921875;
    final pair = [_place(10, 10.8, edge - 0.0003), _place(11, 10.8, edge + 0.0003)];
    expect(groups(PlaceClusterer(pair, mergeDistance: 0).clustersAt(14)), [
      [10],
      [11],
    ]);
    expect(groups(PlaceClusterer(pair).clustersAt(14)), [
      [10, 11],
    ]);
  });
}
