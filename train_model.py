import os
import sys
import csv
import time
import joblib
from sklearn.model_selection import train_test_split
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, classification_report

try:
    sys.stdout.reconfigure(encoding='utf-8')
except AttributeError:
    pass

def load_dataset(csv_path):
    print(f"Đang đọc dữ liệu từ {csv_path}...")
    texts = []
    categories = []
    ratings = []
    sentiments = []
    
    with open(csv_path, mode="r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for row in reader:
            content = row["content"]
            category = row["category"]
            rating = int(row["rating"])
            
            # Chuyển rating thành nhãn cảm xúc
            # 4-5 sao: Tích cực (positive)
            # 3 sao: Trung lập (neutral)
            # 1-2 sao: Tiêu cực (negative)
            if rating >= 4:
                sentiment = "positive"
            elif rating == 3:
                sentiment = "neutral"
            else:
                sentiment = "negative"
                
            texts.append(content)
            categories.append(category)
            ratings.append(rating)
            sentiments.append(sentiment)
            
    print(f"Đã đọc thành công {len(texts)} bản ghi.")
    return texts, categories, sentiments

def train_classifier(X_train, X_test, y_train, y_test, model_name):
    print(f"\n--- Bắt đầu huấn luyện mô hình phân loại {model_name} ---")
    start_time = time.time()
    
    # 1. Vector hóa văn bản bằng TF-IDF
    # ngram_range=(1, 2) giúp mô hình học được các cụm 2 từ (ví dụ: "rất ngon", "quá tệ")
    vectorizer = TfidfVectorizer(ngram_range=(1, 2), max_features=20000)
    X_train_vec = vectorizer.fit_transform(X_train)
    X_test_vec = vectorizer.transform(X_test)
    
    # 2. Huấn luyện mô hình Logistic Regression
    # C=1.0 là tham số điều hòa chuẩn, max_iter=200 để đảm bảo hội tụ
    model = LogisticRegression(max_iter=200, n_jobs=-1)
    model.fit(X_train_vec, y_train)
    
    duration = time.time() - start_time
    print(f"Hoàn thành huấn luyện mô hình trong {duration:.2f} giây.")
    
    # 3. Đánh giá mô hình
    y_pred = model.predict(X_test_vec)
    accuracy = accuracy_score(y_test, y_pred)
    print(f"Độ chính xác (Accuracy): {accuracy:.4f}")
    print("Báo cáo phân loại chi tiết:")
    print(classification_report(y_test, y_pred))
    
    return vectorizer, model

def main():
    csv_path = "comments_dataset.csv"
    
    if not os.path.exists(csv_path):
        print(f"Lỗi: Không tìm thấy file {csv_path}. Vui lòng tạo file dữ liệu trước.")
        return
        
    # Tạo thư mục lưu trữ mô hình
    os.makedirs("models", exist_ok=True)
    
    # Tải dữ liệu
    texts, categories, sentiments = load_dataset(csv_path)
    
    # --- PHẦN 1: HUẤN LUYỆN BỘ PHÂN LOẠI DANH MỤC (CATEGORY CLASSIFIER) ---
    print("\n[PHẦN 1] PHÂN LOẠI DANH MỤC (NHÀ HÀNG, KHÁCH SẠN, QUÁN CAFE)")
    X_train_cat, X_test_cat, y_train_cat, y_test_cat = train_test_split(
        texts, categories, test_size=0.2, random_state=42
    )
    cat_vectorizer, cat_model = train_classifier(
        X_train_cat, X_test_cat, y_train_cat, y_test_cat, "Category"
    )
    
    # --- PHẦN 2: HUẤN LUYỆN BỘ PHÂN LOẠI CẢM XÚC (SENTIMENT CLASSIFIER) ---
    print("\n[PHẦN 2] PHÂN LOẠI CẢM XÚC (TÍCH CỰC, TRUNG LẬP, TIÊU CỰC)")
    X_train_sent, X_test_sent, y_train_sent, y_test_sent = train_test_split(
        texts, sentiments, test_size=0.2, random_state=42
    )
    sent_vectorizer, sent_model = train_classifier(
        X_train_sent, X_test_sent, y_train_sent, y_test_sent, "Sentiment"
    )
    
    # --- LƯU MÔ HÌNH ---
    print("\n--- Đang lưu trữ các mô hình đã huấn luyện vào thư mục models/ ---")
    joblib.dump(cat_vectorizer, "models/category_vectorizer.pkl")
    joblib.dump(cat_model, "models/category_model.pkl")
    joblib.dump(sent_vectorizer, "models/sentiment_vectorizer.pkl")
    joblib.dump(sent_model, "models/sentiment_model.pkl")
    print("Đã lưu tất cả mô hình thành công!")

if __name__ == "__main__":
    main()
