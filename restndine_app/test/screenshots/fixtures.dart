// Dữ liệu giả lập cho bộ chụp màn hình (định dạng giống API thật).

String _iso(Duration ago) => DateTime.now().toUtc().subtract(ago).toIso8601String();

String _vn(Duration ago) {
  final t = DateTime.now().toUtc().subtract(ago).add(const Duration(hours: 7));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.day)}/${two(t.month)}/${t.year} ${two(t.hour)}:${two(t.minute)}';
}

const categories = [
  {'id': 1, 'name': 'Nhà hàng', 'slug': 'restaurant', 'icon': ''},
  {'id': 2, 'name': 'Khách sạn', 'slug': 'hotel', 'icon': ''},
  {'id': 3, 'name': 'Quán cà phê', 'slug': 'cafe', 'icon': ''},
];

Map<String, dynamic> _place(
  int id,
  String name,
  String address,
  double lat,
  double lng,
  int cat, {
  String? image,
  String? price,
  bool sponsored = false,
  int? stars,
  String? phone,
  String? description,
  String? amenities,
}) =>
    {
      'id': id,
      'name': name,
      'address': address,
      'latitude': lat,
      'longitude': lng,
      'description': description,
      'imageUrl': image,
      'phoneNumber': phone,
      'priceRange': price,
      'bannerUrl': sponsored ? 'img/banner' : null,
      'bannerStatus': sponsored ? 2 : 0,
      'starRating': stars,
      'amenities': amenities,
      'categories': [categories[cat - 1]],
    };

final places = [
  _place(1, 'Phở Hòa Pasteur', '260C Pasteur, Phường Võ Thị Sáu, Quận 3, TP.HCM', 10.7880, 106.6894, 1,
      image: 'img/restaurant-1', price: '60.000 - 120.000đ', sponsored: true, phone: '028 3829 7943',
      description: 'Quán phở lâu đời hơn 50 năm giữa lòng Sài Gòn. Nước dùng ninh xương bò 12 tiếng, '
          'bánh phở tươi tráng mỗi sáng, thịt bò tái chín mềm. Không gian rộng, phục vụ nhanh, '
          'phù hợp ăn sáng cùng gia đình hoặc tiếp khách.',
      amenities: 'Wifi miễn phí, Máy lạnh, Chỗ đậu xe máy, Nhận đặt bàn'),
  _place(2, 'The Workshop Coffee', '27 Ngô Đức Kế, Phường Bến Nghé, Quận 1, TP.HCM', 10.7740, 106.7050, 3,
      image: 'img/cafe-2', price: '55.000 - 95.000đ', sponsored: true),
  _place(3, 'Cơm Tấm Ba Ghiền', '84 Đặng Văn Ngữ, Phường 10, Phú Nhuận, TP.HCM', 10.7930, 106.6720, 1,
      image: 'img/restaurant-3', price: '45.000 - 80.000đ'),
  _place(4, 'Khách sạn Rex Sài Gòn', '141 Nguyễn Huệ, Phường Bến Nghé, Quận 1, TP.HCM', 10.7760, 106.7010, 2,
      image: 'img/hotel-1', price: '2.500.000 - 5.000.000đ', stars: 5),
  _place(5, 'Bánh Mì Huỳnh Hoa', '26 Lê Thị Riêng, Phường Phạm Ngũ Lão, Quận 1, TP.HCM', 10.7712, 106.6925, 1,
      image: 'img/restaurant-4', price: '35.000 - 70.000đ'),
  _place(6, 'Cộng Cà Phê', '26 Lý Tự Trọng, Phường Bến Nghé, Quận 1, TP.HCM', 10.7795, 106.7005, 3,
      image: 'img/cafe-1', price: '35.000 - 65.000đ'),
  _place(7, 'Liberty Central Saigon Riverside', '17 Tôn Đức Thắng, Phường Bến Nghé, Quận 1, TP.HCM', 10.7745,
      106.7065, 2, image: 'img/hotel-3', price: '1.800.000 - 3.200.000đ', stars: 4),
  _place(8, 'Lẩu Dê 404', '404 Lê Văn Sỹ, Phường 14, Quận 3, TP.HCM', 10.7860, 106.6790, 1,
      image: 'img/restaurant-2', price: '150.000 - 300.000đ'),
];

Map<String, dynamic> placeDetail(int id) {
  final base = Map<String, dynamic>.from(places.firstWhere((p) => p['id'] == id));
  return {
    ...base,
    'isApproved': true,
    'openingHours': '06:00 - 22:00 (tất cả các ngày)',
    'website': 'phohoapasteur.vn',
    'ownerId': 'owner-1',
    'aiSummaryCache': null,
    'images': [
      {'id': 11, 'imageUrl': 'img/restaurant-2'},
      {'id': 12, 'imageUrl': 'img/restaurant-4'},
    ],
    'comments': [
      _comment(1, 'lan.tran@gmail.com', 5, const Duration(hours: 3), 4,
          'Nước dùng đậm đà, thơm mùi quế hồi mà không bị gắt. Thịt bò tái mềm, bánh phở dai vừa. '
              'Sáng chủ nhật hơi đông nhưng lên món nhanh. Sẽ quay lại!'),
      _comment(2, 'hoang.pham@outlook.com', 4, const Duration(days: 1, hours: 2), 1,
          'Phở ngon, giá hơi cao so với mặt bằng chung nhưng chất lượng xứng đáng.'),
      _comment(3, 'minh.anh@gmail.com', 5, const Duration(days: 3), 0,
          'Quán sạch sẽ, nhân viên thân thiện. Trà đá miễn phí.'),
      _comment(4, 'quoc.bao@gmail.com', 3, const Duration(days: 9), 2,
          'Ăn được, nhưng hôm mình đến nước dùng hơi nguội.'),
      _comment(5, 'thu.ha@yahoo.com', 5, const Duration(days: 20), 0, 'Phở bò viên ngon nhất khu vực!'),
      _comment(6, 'tuan.le@gmail.com', 2, const Duration(days: 40), 0,
          'Chờ khá lâu vào giờ cao điểm, không có chỗ để xe hơi.'),
    ],
  };
}

Map<String, dynamic> _comment(int id, String email, int rating, Duration ago, int helpful, String content) => {
      'id': id,
      'content': content,
      'rating': rating,
      'createdAt': _iso(ago),
      'helpfulCount': helpful,
      'userId': 'u$id',
      'userEmail': email,
    };

Map<String, dynamic> aiSummary() => {
      'success': true,
      'summary': '### Điểm nổi bật\n'
          '- **Nước dùng** đậm đà, thơm, được nhắc đến nhiều nhất.\n'
          '- **Phục vụ nhanh**, nhân viên thân thiện, quán sạch sẽ.\n\n'
          '### Cần cải thiện\n'
          '- Giờ cao điểm phải chờ lâu, chỗ đậu ô tô hạn chế.\n'
          '- Giá cao hơn mặt bằng chung một chút.',
      'isCached': true,
      'updatedAt': _iso(const Duration(hours: 5)),
      'sentimentStats': {'positive': 4, 'neutral': 1, 'negative': 1, 'total': 6},
    };

const customer = {
  'id': 'user-1',
  'email': 'minh.nguyen@gmail.com',
  'userName': 'minh.nguyen@gmail.com',
  'roles': ['Customer'],
};

const owner = {
  'id': 'owner-9',
  'email': 'quan.ly@phohoa.vn',
  'userName': 'quan.ly@phohoa.vn',
  'roles': ['Owner'],
};

List<Map<String, dynamic>> chatMessages() => [
      _msg(1, 'user-1', 'Chào quán, tối nay 7 giờ còn bàn cho 4 người không ạ?', const Duration(days: 1, hours: 3)),
      _msg(2, 'owner-1', 'Dạ chào anh, tối nay quán vẫn còn bàn ạ.', const Duration(days: 1, hours: 2, minutes: 58)),
      _msg(3, 'owner-1', 'Anh cho em xin tên và số điện thoại để giữ bàn nhé.', const Duration(days: 1, hours: 2, minutes: 57)),
      _msg(4, 'user-1', 'Minh, 0903 123 456. Cảm ơn quán!', const Duration(days: 1, hours: 2, minutes: 50)),
      _msg(5, 'user-1', 'Quán có chỗ đậu ô tô gần đó không ạ?', const Duration(minutes: 25)),
      _msg(6, 'owner-1', 'Dạ có bãi giữ xe ngay đầu hẻm, cách quán khoảng 50m ạ.', const Duration(minutes: 20)),
    ];

Map<String, dynamic> _msg(int id, String sender, String content, Duration ago) => {
      'id': id,
      'senderId': sender,
      'senderEmail': sender == 'owner-1' ? 'owner@phohoa.vn' : 'minh.nguyen@gmail.com',
      'receiverId': sender == 'owner-1' ? 'user-1' : 'owner-1',
      'receiverEmail': '',
      'content': content,
      'sentAt': _vn(ago),
      'isRead': true,
    };
