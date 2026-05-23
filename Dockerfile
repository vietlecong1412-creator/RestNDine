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
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
EXPOSE 8080
EXPOSE 8081

# Cấu hình ASP.NET Core lắng nghe cổng 8080 (cổng mặc định trên Render/Railway)
ENV ASPNETCORE_URLS=http://+:8080

# Cài đặt Python 3 và pip
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3 python3-pip python3-venv && \
    rm -rf /var/lib/apt/lists/*

# Cài đặt các thư viện học máy Python trực tiếp vào container
RUN pip3 install --no-cache-dir scikit-learn joblib --break-system-packages

# Sao chép kết quả build từ Stage 1
COPY --from=build /app/publish .

# Sao chép kịch bản phân tích Python và các mô hình đã huấn luyện (.pkl) vào đúng thư mục models (chữ thường)
COPY analyze_reviews.py .
COPY Models/*.pkl ./models/

# Thiết lập quyền thực thi
RUN chmod +x analyze_reviews.py

# Khởi chạy ứng dụng Web C#
ENTRYPOINT ["dotnet", "DACS.dll"]
