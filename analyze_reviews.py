import os
import sys
import re
import joblib
from transformers import pipeline
from text_preprocess import normalize

try:
    sys.stdin.reconfigure(encoding='utf-8')
    sys.stdout.reconfigure(encoding='utf-8')
except AttributeError:
    pass

# Định nghĩa các từ khóa đặc trưng cho từng khía cạnh
ASPECT_KEYWORDS = {
    "food_room": [
        "món ăn", "đồ ăn", "nêm nếm", "steak", "sốt", "tiêu đen", "hải sản", "thịt", "ngọt", "thực đơn", 
        "nóng hổi", "trang trí", "lẩu", "chua cay", "nhúng", "gia vị", "ướp", "súp", "nhạt", "nướng", 
        "nước chấm", "xương", "phòng", "giường", "đệm", "nội thất", "thiết kế", "minibar", "bồn tắm", 
        "ban công", "cách âm", "yên tĩnh", "điều hòa", "ga trải giường", "gối", "vòi sen", "ẩm mốc", 
        "gián", "kiến", "tường", "nấm mốc", "cà phê", "cốt dừa", "pha chế", "trà", "hoa quả", "trái cây", 
        "bánh ngọt", "tiramisu", "mousse", "chanh leo", "bạc xỉu", "trà sữa", "trân châu", "sinh tố", "xoài", "syrup"
    ],
    "service": [
        "nhân viên", "phục vụ", "nhiệt tình", "lên món", "châm nước", "dọn đĩa", "dịch vụ", "chăm sóc", 
        "giới thiệu", "lóng ngóng", "lễ phép", "đón tiếp", "đổi bàn", "chậm", "nhắc", "order", "đợi", 
        "thờ ơ", "thu ngân", "quản lý", "lễ tân", "check-in", "hành lý", "dọn phòng", "ngăn nắp", 
        "hồ bơi", "gym", "spa", "sửa bóng đèn", "lịch sự", "thân thiện", "giặt ủi", "hủy phòng", 
        "cười", "dọn ly", "dắt xe", "tư vấn", "laptop", "chờ", "bảo vệ"
    ],
    "ambiance_price": [
        "không gian", "ấm cúng", "sang trọng", "hẹn hò", "view", "check-in", "giá cả", "chất lượng", 
        "sạch sẽ", "máy lạnh", "bàn ghế", "nhạc", "thư giãn", "thoáng đãng", "vừa túi tiền", 
        "ồn ào", "chật chội", "nhà vệ sinh", "vị trí", "trung tâm", "khuôn viên", "cây xanh", 
        "buffet", "giá phòng", "wifi", "công trình", "bụi bặm", "chill", "lung linh", "tối giản", 
        "mát mẻ", "khói thuốc"
    ]
}

ASPECT_NAMES = {
    "food_room": "Đồ ăn & Phòng ốc (Food/Room)",
    "service": "Dịch vụ khách hàng (Service)",
    "ambiance_price": "Không gian & Giá cả (Ambiance/Price)"
}

def split_into_sentences(text):
    # Tách các câu dựa trên dấu chấm, chấm hỏi, chấm than
    sentences = re.split(r'(?<=[.!?])\s+', text)
    return [s.strip() for s in sentences if s.strip()]

def get_aspect(sentence):
    sentence_lower = sentence.lower()
    scores = {"food_room": 0, "service": 0, "ambiance_price": 0}
    
    for aspect, keywords in ASPECT_KEYWORDS.items():
        for keyword in keywords:
            if keyword in sentence_lower:
                scores[aspect] += 1
                
    # Chọn khía cạnh có điểm khớp từ khóa cao nhất
    max_score = max(scores.values())
    if max_score > 0:
        for aspect, score in scores.items():
            if score == max_score:
                return aspect
    return None

class ABSAAnalyzer:
    def __init__(self, models_dir="models"):
        self.models_dir = models_dir
        self.load_models()
        
    def load_models(self):
        try:
            self.cat_vectorizer = joblib.load(os.path.join(self.models_dir, "category_vectorizer.pkl"))
            self.cat_model = joblib.load(os.path.join(self.models_dir, "category_model.pkl"))
            
            # Deep Learning PhoBERT transformer pipeline for sentiment classification
            self.nlp_sentiment = pipeline("sentiment-analysis", model="wonrax/phobert-base-vietnamese-sentiment")
        except Exception as e:
            print(f"Lỗi khi tải mô hình: {e}")
            print("Vui lòng chắc chắn rằng bạn đã chạy train_model.py thành công và cài đặt đầy đủ các thư viện.")
            sys.exit(1)
            
    def predict_sentiment(self, text):
        try:
            if not text or not text.strip():
                return "neutral"
            text = normalize(text)
            res = self.nlp_sentiment(text, truncation=True, max_length=256)[0]
            label = res["label"].upper()
            
            if "POS" in label:
                return "positive"
            elif "NEG" in label:
                return "negative"
            else:
                return "neutral"
        except Exception as e:
            print(f"Lỗi khi dự đoán cảm xúc với PhoBERT: {e}", file=sys.stderr)
            return "neutral"

    def analyze_comment(self, comment):
        # 1. Dự đoán category và sentiment cho toàn bộ bình luận
        cat_vec = self.cat_vectorizer.transform([comment])
        predicted_cat = self.cat_model.predict(cat_vec)[0]
        
        # Dự đoán cảm xúc bằng mô hình học sâu PhoBERT
        predicted_sent = self.predict_sentiment(comment)
        
        # 2. Phân tích khía cạnh (ABSA) bằng cách tách câu
        sentences = split_into_sentences(comment)
        aspect_analyses = []
        
        for sent in sentences:
            aspect = get_aspect(sent)
            if aspect:
                # Dự đoán sentiment của từng câu khía cạnh riêng lẻ bằng PhoBERT
                sent_sentiment = self.predict_sentiment(sent)
                aspect_analyses.append({
                    "sentence": sent,
                    "aspect": aspect,
                    "sentiment": sent_sentiment
                })
                
        return {
            "comment": comment,
            "category": predicted_cat,
            "sentiment": predicted_sent,
            "aspects": aspect_analyses
        }

    def aggregate_reviews(self, reviews_list):
        total_reviews = len(reviews_list)
        if total_reviews == 0:
            return None
            
        category_counts = {}
        overall_sentiment_counts = {"positive": 0, "neutral": 0, "negative": 0}
        
        # Lưu trữ thống kê khía cạnh
        # aspect_stats = { aspect: { sentiment: count } }
        aspect_stats = {
            "food_room": {"positive": 0, "neutral": 0, "negative": 0},
            "service": {"positive": 0, "neutral": 0, "negative": 0},
            "ambiance_price": {"positive": 0, "neutral": 0, "negative": 0}
        }
        
        highlights = {"positive": [], "negative": []}
        
        for review in reviews_list:
            res = self.analyze_comment(review)
            
            # Đếm category
            cat = res["category"]
            category_counts[cat] = category_counts.get(cat, 0) + 1
            
            # Đếm sentiment tổng thể
            sent = res["sentiment"]
            overall_sentiment_counts[sent] += 1
            
            # Lưu các bình luận làm điểm nhấn nổi bật
            if sent == "positive" and len(highlights["positive"]) < 3:
                highlights["positive"].append(review)
            elif sent == "negative" and len(highlights["negative"]) < 3:
                highlights["negative"].append(review)
                
            # Đếm khía cạnh chi tiết
            for asp_res in res["aspects"]:
                asp = asp_res["aspect"]
                asp_sent = asp_res["sentiment"]
                aspect_stats[asp][asp_sent] += 1
                
        # Xác định category chiếm ưu thế
        dominant_category = max(category_counts, key=category_counts.get) if category_counts else "Không xác định"
        
        return {
            "total_reviews": total_reviews,
            "category": dominant_category,
            "category_counts": category_counts,
            "overall_sentiment": overall_sentiment_counts,
            "aspect_stats": aspect_stats,
            "highlights": highlights
        }

def print_dashboard(report):
    if not report:
        print("Không có dữ liệu để lập báo cáo.")
        return
        
    print("\n" + "="*60)
    print("      BÁO CÁO TỔNG HỢP & PHÂN TÍCH KHÍA CẠNH ĐÁNH GIÁ      ")
    print("="*60)
    print(f"Tổng số bình luận phân tích : {report['total_reviews']}")
    print(f"Lĩnh vực dịch vụ xác định   : {report['category'].upper()}")
    
    # 1. Cảm xúc tổng thể
    total = report['total_reviews']
    sent = report['overall_sentiment']
    pos_pct = (sent['positive'] / total) * 100
    neu_pct = (sent['neutral'] / total) * 100
    neg_pct = (sent['negative'] / total) * 100
    
    print("\n--- [1] Chỉ Số Cảm Xúc Tổng Thể ---")
    print(f"🟢 Tích cực  : {sent['positive']:>4} ({pos_pct:.1f}%)")
    print(f"🟡 Trung lập : {sent['neutral']:>4} ({neu_pct:.1f}%)")
    print(f"🔴 Tiêu cực  : {sent['negative']:>4} ({neg_pct:.1f}%)")
    
    # Vẽ thanh tiến trình cảm xúc trực quan
    bar_pos = int(pos_pct / 5)
    bar_neu = int(neu_pct / 5)
    bar_neg = int(neg_pct / 5)
    print("[" + "█"*bar_pos + "░"*bar_neu + "▒"*bar_neg + "] (Tích cực | Trung lập | Tiêu cực)")
    
    # 2. Phân tích khía cạnh chi tiết
    print("\n--- [2] Phân Tích Cảm Xúc Theo Khía Cạnh (ABSA) ---")
    for asp_key, stats in report['aspect_stats'].items():
        asp_total = sum(stats.values())
        name = ASPECT_NAMES[asp_key]
        print(f"\n* {name}:")
        if asp_total == 0:
            print("  (Không có đủ dữ liệu nhắc đến khía cạnh này)")
            continue
            
        a_pos_p = (stats['positive'] / asp_total) * 100
        a_neu_p = (stats['neutral'] / asp_total) * 100
        a_neg_p = (stats['negative'] / asp_total) * 100
        
        print(f"  🟢 Tích cực  : {stats['positive']:>3} ({a_pos_p:.1f}%)")
        print(f"  🟡 Trung lập : {stats['neutral']:>3} ({a_neu_p:.1f}%)")
        print(f"  🔴 Tiêu cực  : {stats['negative']:>3} ({a_neg_p:.1f}%)")
        
    # 3. Tóm tắt & Điểm nhấn tiêu biểu
    print("\n--- [3] Điểm Nhấn & Đánh Giá Tiêu Biểu ---")
    if report['highlights']['positive']:
        print("\n👍 Khen ngợi nổi bật từ khách hàng:")
        for idx, h in enumerate(report['highlights']['positive'], 1):
            print(f"  {idx}. \"{h}\"")
            
    if report['highlights']['negative']:
        print("\n👎 Điểm cần cải thiện nhiều nhất:")
        for idx, h in enumerate(report['highlights']['negative'], 1):
            print(f"  {idx}. \"{h}\"")
            
    print("="*60 + "\n")

def main():
    import json
    
    # Nếu chạy kèm cờ --json, đọc dữ liệu đánh giá dạng JSON array từ stdin và trả về JSON kết quả
    if len(sys.argv) > 1 and sys.argv[1] == "--json":
        try:
            input_data = sys.stdin.read().strip()
            reviews = json.loads(input_data)
            analyzer = ABSAAnalyzer()
            report = analyzer.aggregate_reviews(reviews)
            print(json.dumps(report, ensure_ascii=False))
        except Exception as e:
            print(json.dumps({"error": str(e)}, ensure_ascii=False))
        return

    # Khởi tạo bộ phân tích demo
    analyzer = ABSAAnalyzer()
    
    # Demo thử nghiệm với các đánh giá nhập tay
    sample_reviews = [
        "Đồ ăn ở đây ngon lắm, đặc biệt là steak bò mềm mọng nước! Nhân viên phục vụ rất chu đáo và nhiệt tình, tuy nhiên giá hơi đắt một chút.",
        "Không gian quán siêu đẹp và chill, chụp ảnh check-in cực đỉnh. Nhưng nước uống trà sữa trân châu thì quá ngọt gắt, trân châu bị cứng không nuốt nổi.",
        "Tôi cực kỳ phẫn nộ với thái độ của nhân viên phục vụ ở đây, coi thường khách hàng ra mặt và cãi nhau tay đôi. Đồ ăn thì nguội ngắt và nhiều dầu mỡ. Sẽ không bao giờ quay lại!",
        "Phòng khách sạn sạch sẽ, cách âm tốt nên ngủ rất êm giấc. Lễ tân thân thiện hỗ trợ xách hành lý nhiệt tình. Giá cả cực kỳ hợp lý so với chất lượng nghỉ dưỡng 5 sao này.",
        "Vị trí khách sạn rất đẹp gần trung tâm, buffet sáng ăn ngon miệng. Nhưng nhà vệ sinh bị rò nước và điều hòa chạy ồn quá.",
    ]
    
    print("Đang chạy phân tích thử nghiệm trên danh sách đánh giá mẫu...")
    report = analyzer.aggregate_reviews(sample_reviews)
    print_dashboard(report)
    
if __name__ == "__main__":
    main()
