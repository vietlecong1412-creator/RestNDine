# ============================================================
# Stage 1: Build C# .NET Application
# ============================================================
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Sao chép các tệp tin cấu hình và restore dependencies
COPY ["DACS.csproj", "./"]
RUN dotnet restore "DACS.csproj"

# Sao chép toàn bộ mã nguồn và biên dịch dự án
COPY . .
RUN dotnet publish "DACS.csproj" -c Release -o /app/publish /p:UseAppHost=false

# ============================================================
# Stage 2: Runtime Environment (.NET 10.0 + Python 3 + ML Libraries)
# ============================================================
# Tag noble (Ubuntu 24.04) cố định Python 3.12, là bản có đủ thư viện trong requirements-ai.txt
FROM mcr.microsoft.com/dotnet/aspnet:10.0-noble AS final
WORKDIR /app
EXPOSE 8080
EXPOSE 8081

# Cấu hình ASP.NET Core lắng nghe cổng 8080 (cổng mặc định trên Render/Railway)
ENV ASPNETCORE_URLS=http://+:8080

# Cài đặt Python 3 và pip
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3 python3-pip python3-venv && \
    rm -rf /var/lib/apt/lists/* && \
    ln -sf /usr/bin/python3 /usr/local/bin/python

# Cài đặt các thư viện học máy Python trực tiếp vào container
COPY requirements-ai.txt .
RUN pip3 install --no-cache-dir -r requirements-ai.txt --break-system-packages

# Tải sẵn PhoBERT vào image (khoảng 500 MB) để khi chạy không phải tải lại
ENV HF_HOME=/app/.hf-cache
RUN python3 -c "from transformers import pipeline; pipeline('sentiment-analysis', model='wonrax/phobert-base-vietnamese-sentiment')"
ENV TRANSFORMERS_OFFLINE=1
ENV HF_HUB_OFFLINE=1

# Sao chép kết quả build từ Stage 1
COPY --from=build /app/publish .

# Sao chép kịch bản phân tích Python và các mô hình đã huấn luyện (.pkl) vào đúng thư mục models (chữ thường)
COPY analyze_reviews.py text_preprocess.py ./
COPY Models/*.pkl ./models/

# CA công khai của Supabase, dùng cho SSL Mode=VerifyFull trong chuỗi kết nối
COPY certs/prod-ca-2021.crt ./certs/

# Thiết lập quyền thực thi
RUN chmod +x analyze_reviews.py

# Chạy thử AI ngay lúc build: AI không chạy được thì build thất bại, thay vì âm thầm dùng bản dự phòng khi triển khai
RUN echo '["Đồ ăn rất ngon, nhân viên thân thiện."]' | python3 analyze_reviews.py --json | grep -q overall_sentiment

# Khởi chạy ứng dụng Web C#
ENTRYPOINT ["dotnet", "DACS.dll"]
