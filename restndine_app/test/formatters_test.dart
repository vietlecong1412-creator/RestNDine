import 'package:flutter_test/flutter_test.dart';
import 'package:restndine_app/models/chat_message_model.dart';
import 'package:restndine_app/models/place_model.dart';
import 'package:restndine_app/utils/formatters.dart';

void main() {
  group('foldVietnamese', () {
    test('bỏ dấu và chữ hoa', () {
      expect(foldVietnamese('Phở Hòa PASTEUR'), 'pho hoa pasteur');
      expect(foldVietnamese('Cơm Tấm Ba Ghiền'), 'com tam ba ghien');
      expect(foldVietnamese('Đường Ưu Đàm'), 'duong uu dam');
    });

    test('xử lý chuỗi dạng tổ hợp (NFD)', () {
      // "ở" viết bằng o + dấu móc (U+031B) + dấu hỏi (U+0309)
      expect(foldVietnamese('Phở'), 'pho');
    });
  });

  group('giờ từ server', () {
    test('chuỗi không ghi múi giờ được coi là UTC', () {
      final a = parseServerDate('2026-11-09T03:00:00')!;
      final b = parseServerDate('2026-11-09T03:00:00Z')!;
      expect(a, b);
      expect(a.toUtc().hour, 3);
    });

    test('đọc được 7 chữ số phần giây của .NET', () {
      expect(parseServerDate('2026-11-09T03:00:00.1234567Z')!.toUtc().minute, 0);
    });

    test('giờ chat "dd/MM/yyyy HH:mm" là giờ Việt Nam (UTC+7)', () {
      final t = parseVietnamDateTime('09/11/2026 10:30')!.toUtc();
      expect([t.year, t.month, t.day, t.hour, t.minute], [2026, 11, 9, 3, 30]);
    });

    test('tin nhắn giữ đúng giờ gửi thay vì lấy giờ hiện tại', () {
      final msg = ChatMessageModel.fromJson({'id': 1, 'content': 'x', 'sentAt': '01/02/2026 08:05'});
      expect(msg.sentAt.toUtc(), DateTime.utc(2026, 2, 1, 1, 5));
    });
  });

  group('timeAgo', () {
    final now = DateTime(2026, 11, 9, 20, 0);

    test('các mốc thời gian', () {
      expect(timeAgo(now.subtract(const Duration(seconds: 20)), now: now), 'Vừa xong');
      expect(timeAgo(now.subtract(const Duration(minutes: 5)), now: now), '5 phút trước');
      expect(timeAgo(now.subtract(const Duration(hours: 3)), now: now), '3 giờ trước');
      expect(timeAgo(DateTime(2026, 11, 8, 9), now: now), 'Hôm qua');
      expect(timeAgo(DateTime(2026, 11, 5, 9), now: now), '4 ngày trước');
      expect(timeAgo(DateTime(2026, 10, 20), now: now), '2 tuần trước');
      expect(timeAgo(DateTime(2026, 8, 1), now: now), '01/08/2026');
    });
  });

  test('tên hiển thị không lộ email', () {
    expect(displayNameFromEmail('minh.nguyen@gmail.com'), 'minh.nguyen');
    expect(initialsOf('minh.nguyen'), 'MN');
    expect(initialsOf('lan'), 'L');
  });

  group('PlaceModel', () {
    PlaceModel place({List<int> ratings = const [], String? amenities, int? stars}) => PlaceModel.fromJson({
          'id': 3,
          'name': 'Khách sạn Rex',
          'latitude': 10.77,
          'longitude': 106.70,
          'bannerStatus': 0,
          'starRating': stars,
          'amenities': amenities,
          'categories': [
            {'id': 2, 'name': 'Khách sạn', 'slug': 'hotel', 'icon': ''},
          ],
          'comments': [
            for (var i = 0; i < ratings.length; i++)
              {'id': i, 'content': 'ok', 'rating': ratings[i], 'createdAt': '2026-11-01T00:00:00Z'},
          ],
        });

    test('điểm trung bình tính từ đánh giá, không dùng hạng sao khách sạn', () {
      final p = place(ratings: [5, 4, 3], stars: 5);
      expect(p.averageRating, 4);
      expect(p.ratingDistribution, [0, 0, 1, 1, 1]);
      expect(p.type, PlaceType.hotel);
    });

    test('làm sạch địa chỉ cào từ Google Maps', () {
      expect(PlaceModel.cleanAddress('Việt Nam'), isNull);
      expect(PlaceModel.cleanAddress('Khách sạn 5 sao'), isNull);
      expect(PlaceModel.cleanAddress('Khách sạn 5 sao · '), isNull);
      expect(PlaceModel.cleanAddress('Quán cà phê · 58, Đ. Số 9/22 22'), '58, Đ. Số 9/22 22');
      expect(PlaceModel.cleanAddress('141 Nguyễn Huệ, Quận 1'), '141 Nguyễn Huệ, Quận 1');
      // Điểm đánh giá + mức giá của Google không phải địa chỉ
      expect(PlaceModel.cleanAddress('4,3(113) · 100-200 N ₫'), isNull);
      expect(PlaceModel.cleanAddress('Nhà hàng ·  · 32-34 Ngô Đức Kế'), '32-34 Ngô Đức Kế');
      // Loại hình bất kỳ ("Món ăn Việt Nam", "Quán ăn nhỏ") bị bỏ; "Quận" thì giữ
      expect(PlaceModel.cleanAddress('Món ăn Việt Nam · Mở cả ngày'), isNull);
      expect(PlaceModel.cleanAddress('Quán ăn nhỏ · Chợ Bến Thành, Quận Một'), 'Chợ Bến Thành, Quận Một');
    });

    test('"Liên hệ" không được coi là mức giá', () {
      PlaceModel withPrice(String? price) => PlaceModel.fromJson({
            'id': 1,
            'name': 'A',
            'priceRange': price,
            'bannerStatus': 0,
            'categories': [],
          });
      expect(withPrice('Liên hệ').displayPrice, isNull);
      expect(withPrice('  liên hệ ').displayPrice, isNull);
      expect(withPrice('30k - 70k').displayPrice, '30k - 70k');
    });

    test('tiện ích ngắn tách thành danh sách, đoạn văn dài thì giữ nguyên', () {
      expect(place(amenities: 'Wifi, Hồ bơi; Bãi đỗ xe').amenityList, ['Wifi', 'Hồ bơi', 'Bãi đỗ xe']);
      expect(
        place(amenities: 'Khách sạn có hồ bơi vô cực trên tầng thượng nhìn ra sông Sài Gòn, phòng gym').amenityList,
        isEmpty,
      );
    });
  });
}
