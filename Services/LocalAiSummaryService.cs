using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.Extensions.Caching.Memory;

namespace DACS.Services
{
    public class LocalAiSummaryService : IAiSummaryService
    {
        private readonly IMemoryCache _cache;

        public LocalAiSummaryService(IMemoryCache cache)
        {
            _cache = cache;
        }

        public class PythonReport
        {
            public int total_reviews { get; set; }
            public string category { get; set; }
            public Dictionary<string, int> overall_sentiment { get; set; }
            public Dictionary<string, Dictionary<string, int>> aspect_stats { get; set; }
            public Dictionary<string, List<string>> highlights { get; set; }
        }

        public async Task<string> SummarizeReviewsAsync(string placeName, IEnumerable<string> reviews)
        {
            var reviewList = reviews?.Where(r => !string.IsNullOrWhiteSpace(r)).ToList() ?? new List<string>();
            if (!reviewList.Any())
            {
                return "📍 Chưa có đủ đánh giá từ cộng đồng để AI tiến hành phân tích. Hãy là người đầu tiên chia sẻ cảm nhận của bạn!";
            }

            // Create a self-invalidating cache key using sorted reviews combination
            var sortedReviews = reviewList.OrderBy(r => r).ToList();
            var reviewsCombined = string.Join("|", sortedReviews);
            var reviewsHash = reviewsCombined.GetHashCode();
            var cacheKey = $"AiSummary_{placeName}_{reviewsHash}";

            if (_cache.TryGetValue(cacheKey, out string? cachedSummary) && !string.IsNullOrEmpty(cachedSummary))
            {
                return cachedSummary;
            }

            // ── BƯỚC 1: Cố gắng chạy mô hình AI Học máy bằng Python ──
            var pythonOutput = await RunPythonAnalysisAsync(reviewList);
            string summary;

            if (!string.IsNullOrEmpty(pythonOutput))
            {
                try
                {
                    var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                    var report = JsonSerializer.Deserialize<PythonReport>(pythonOutput, options);
                    if (report != null && report.overall_sentiment != null)
                    {
                        summary = FormatPythonReport(report);
                        _cache.Set(cacheKey, summary, TimeSpan.FromHours(6)); // Cache for up to 6 hours
                        return summary;
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Lỗi khi phân tích JSON kết quả AI Python: {ex.Message}");
                }
            }

            // ── BƯỚC 2: Bộ Phân Tích dự phòng (Rule-based C#) ──
            summary = GetRuleBasedFallback(reviewList);
            _cache.Set(cacheKey, summary, TimeSpan.FromHours(6)); // Cache for up to 6 hours
            return summary;
        }

        private async Task<string?> RunPythonAnalysisAsync(List<string> reviews)
        {
            string[] pythonExecutables = { "python", "python3" };
            string jsonInput = JsonSerializer.Serialize(reviews);

            foreach (var pyExec in pythonExecutables)
            {
                try
                {
                    var startInfo = new ProcessStartInfo
                    {
                        FileName = pyExec,
                        Arguments = "analyze_reviews.py --json",
                        RedirectStandardInput = true,
                        RedirectStandardOutput = true,
                        RedirectStandardError = true,
                        UseShellExecute = false,
                        CreateNoWindow = true,
                        WorkingDirectory = Directory.GetCurrentDirectory()
                    };

                    using var process = Process.Start(startInfo);
                    if (process == null) continue;

                    // Gửi danh sách bình luận qua Standard Input để tránh giới hạn tham số CLI
                    await using (var writer = process.StandardInput)
                    {
                        await writer.WriteAsync(jsonInput);
                    }

                    var jsonOutput = await process.StandardOutput.ReadToEndAsync();
                    var errorOutput = await process.StandardError.ReadToEndAsync();
                    await process.WaitForExitAsync();

                    if (process.ExitCode == 0 && !string.IsNullOrWhiteSpace(jsonOutput) && !jsonOutput.Contains("\"error\""))
                    {
                        return jsonOutput;
                    }

                    Console.WriteLine($"Lỗi khi chạy Python {pyExec}: {errorOutput}");
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Không thể thực thi lệnh Python {pyExec}: {ex.Message}");
                }
            }

            return null; // Trả về null để kích hoạt chế độ dự phòng C#
        }

        private string FormatPythonReport(PythonReport report)
        {
            var total = report.total_reviews;
            var sent = report.overall_sentiment;
            
            int pos = sent.GetValueOrDefault("positive", 0);
            int neu = sent.GetValueOrDefault("neutral", 0);
            int neg = sent.GetValueOrDefault("negative", 0);
            
            double posPct = total > 0 ? (pos * 100.0 / total) : 0;
            double neuPct = total > 0 ? (neu * 100.0 / total) : 0;
            double negPct = total > 0 ? (neg * 100.0 / total) : 0;

            var sb = new StringBuilder();
            sb.AppendLine($"📊 **Báo cáo phân tích tự động từ FoodRadar Deep Learning AI (Transformer - PhoBERT)**");
            sb.AppendLine($"Dựa trên phân tích ngữ cảnh chuyên sâu của **{total} đánh giá** từ cộng đồng khách hàng:");
            sb.AppendLine();
            sb.AppendLine($"🟢 **Tích cực:** {posPct:F1}% ({pos} bình luận)");
            sb.AppendLine($"🟡 **Trung lập:** {neuPct:F1}% ({neu} bình luận)");
            sb.AppendLine($"🔴 **Tiêu cực:** {negPct:F1}% ({neg} bình luận)");
            sb.AppendLine();

            // 1. Phân tích khía cạnh chuyên sâu
            sb.AppendLine("📌 **Cảm nhận của khách hàng theo từng khía cạnh (ABSA):**");
            foreach (var asp in report.aspect_stats)
            {
                var name = asp.Key switch
                {
                    "food_room" => "🍔 Đồ ăn & Phòng ốc (Food/Room)",
                    "service" => "🛎️ Dịch vụ khách hàng (Service)",
                    "ambiance_price" => "💰 Không gian & Giá cả (Ambiance/Price)",
                    _ => asp.Key
                };

                var stats = asp.Value;
                int aPos = stats.GetValueOrDefault("positive", 0);
                int aNeu = stats.GetValueOrDefault("neutral", 0);
                int aNeg = stats.GetValueOrDefault("negative", 0);
                int aTotal = aPos + aNeu + aNeg;

                if (aTotal > 0)
                {
                    double aPosPct = (aPos * 100.0 / aTotal);
                    sb.AppendLine($"- **{name}:** {aPosPct:F0}% hài lòng (Dựa trên {aTotal} câu thảo luận)");
                }
            }
            sb.AppendLine();

            // 2. Điểm nhấn khen ngợi tiêu biểu
            var highlights = report.highlights;
            if (highlights != null)
            {
                if (highlights.TryGetValue("positive", out var posHighlights) && posHighlights.Any())
                {
                    sb.AppendLine("💚 **Ưu điểm nổi bật:**");
                    foreach (var h in posHighlights.Take(2))
                    {
                        sb.AppendLine($"- *\"{h.Trim()}\"*");
                    }
                    sb.AppendLine();
                }

                if (highlights.TryGetValue("negative", out var negHighlights) && negHighlights.Any())
                {
                    sb.AppendLine("⚠️ **Điểm cần lưu ý:**");
                    foreach (var h in negHighlights.Take(2))
                    {
                        sb.AppendLine($"- *\"{h.Trim()}\"*");
                    }
                    sb.AppendLine();
                }
            }

            // 3. Lời khuyên
            sb.Append("💡 **Gợi ý dành cho bạn:** ");
            if (posPct >= 70)
            {
                sb.AppendLine("Đây là một địa điểm tuyệt vời, nhận được sự hài lòng cực kỳ cao từ cộng đồng. Rất xứng đáng để trải nghiệm ngay lập tức!");
            }
            else if (negPct >= 30)
            {
                sb.AppendLine("Một số khách hàng phản hồi chưa tốt về dịch vụ hoặc chất lượng tại đây. Bạn nên cân nhắc đọc thêm các bình luận chi tiết trước khi quyết định.");
            }
            else
            {
                sb.AppendLine("Chất lượng dịch vụ ở mức ổn định và trung bình khá, thích hợp cho các nhu cầu cơ bản.");
            }

            return sb.ToString();
        }

        private string GetRuleBasedFallback(List<string> reviewList)
        {
            // Từ điển phân tích từ khoá tiếng Việt của C# Fallback
            var positives = new Dictionary<string, string[]>
            {
                { "ngon", new[] { "ngon", "vừa miệng", "hấp dẫn", "tuyệt vời", "xuất sắc", "đậm đà" } },
                { "rẻ", new[] { "rẻ", "hợp lý", "bình dân", "giá tốt", "phải chăng" } },
                { "đẹp", new[] { "đẹp", "view", "xinh", "dễ thương", "chill", "thoáng", "rộng" } },
                { "thân thiện", new[] { "thân thiện", "nhiệt tình", "chu đáo", "nhân viên", "dễ thương", "vui vẻ" } },
                { "sạch sẽ", new[] { "sạch", "thơm", "ngăn nắp", "vệ sinh" } },
                { "nhanh", new[] { "nhanh", "liền", "lẹ", "không đợi lâu" } },
                { "sang trọng", new[] { "sang", "xịn", "đẳng cấp", "cao cấp", "quý phái" } },
                { "tiện nghi", new[] { "tiện nghi", "đầy đủ", "hồ bơi", "spa", "gym", "bể bơi", "wifi mạnh" } }
            };

            var negatives = new Dictionary<string, string[]>
            {
                { "đợi lâu", new[] { "chờ lâu", "đợi lâu", "lâu", "chậm" } },
                { "giá hơi cao", new[] { "đắt", "mắc", "giá cao", "hơi chát" } },
                { "hơi ồn", new[] { "ồn", "náo nhiệt", "đông đúc" } },
                { "hơi chật", new[] { "chật", "nhỏ", "hẹp" } },
                { "wifi yếu", new[] { "wifi yếu", "mạng yếu", "mạng chập chờn" } },
                { "nóng", new[] { "nóng", "bí", "ngột ngạt" } },
                { "thái độ phục vụ", new[] { "thái độ", "phục vụ kém", "khó chịu" } }
            };

            var positiveCounts = new Dictionary<string, int>();
            var negativeCounts = new Dictionary<string, int>();

            foreach (var key in positives.Keys) positiveCounts[key] = 0;
            foreach (var key in negatives.Keys) negativeCounts[key] = 0;

            foreach (var review in reviewList)
            {
                var lowerReview = review.ToLower();

                foreach (var kvp in positives)
                {
                    if (kvp.Value.Any(keyword => lowerReview.Contains(keyword)))
                    {
                        positiveCounts[kvp.Key]++;
                    }
                }

                foreach (var kvp in negatives)
                {
                    if (kvp.Value.Any(keyword => lowerReview.Contains(keyword)))
                    {
                        negativeCounts[kvp.Key]++;
                    }
                }
            }

            var topPositives = positiveCounts.Where(x => x.Value > 0).OrderByDescending(x => x.Value).Select(x => x.Key).ToList();
            var topNegatives = negativeCounts.Where(x => x.Value > 0).OrderByDescending(x => x.Value).Select(x => x.Key).ToList();

            var sb = new StringBuilder();
            sb.AppendLine($"📊 **Báo cáo phân tích tự động từ FoodRadar AI (Rule-based Fallback)**");
            sb.AppendLine($"Dựa trên phân tích nội dung của **{reviewList.Count} đánh giá** thực tế từ cộng đồng khách hàng:");
            sb.AppendLine();

            if (topPositives.Any())
            {
                sb.Append("💚 **Ưu điểm nổi bật:** Khách hàng đánh giá rất cao địa điểm này về ");
                for (int i = 0; i < topPositives.Count; i++)
                {
                    sb.Append($"**{topPositives[i]}**");
                    if (i < topPositives.Count - 2) sb.Append(", ");
                    else if (i == topPositives.Count - 2) sb.Append(" và ");
                }
                sb.AppendLine(". Các bình luận thường mô tả trải nghiệm vô cùng hài lòng, dễ chịu.");
            }
            else
            {
                sb.AppendLine("💚 **Ưu điểm nổi bật:** Địa điểm có chất lượng dịch vụ ở mức ổn định, đáp ứng tốt nhu cầu cơ bản của khách hàng.");
            }
            sb.AppendLine();

            if (topNegatives.Any())
            {
                sb.Append("⚠️ **Điểm cần lưu ý:** Tuy nhiên, một số khách hàng có phản hồi nhẹ về tình trạng ");
                for (int i = 0; i < topNegatives.Count; i++)
                {
                    sb.Append($"**{topNegatives[i]}**");
                    if (i < topNegatives.Count - 2) sb.Append(", ");
                    else if (i == topNegatives.Count - 2) sb.Append(" hoặc ");
                }
                sb.AppendLine(". Bạn nên cân nhắc sắp xếp thời gian hoặc chuẩn bị trước để có trải nghiệm trọn vẹn nhất.");
            }
            else
            {
                sb.AppendLine("⚠️ **Điểm cần lưu ý:** Hiện tại chưa ghi nhận phản hồi tiêu cực hay bất tiện nào đáng kể từ khách hàng tại địa điểm này.");
            }
            sb.AppendLine();

            sb.Append("💡 **Gợi ý dành cho bạn:** ");
            if (topPositives.Contains("ngon") || topPositives.Contains("đẹp"))
            {
                sb.AppendLine("Đây là một địa điểm lý tưởng để check-in, hẹn hò hoặc gặp gỡ người thân để thưởng thức dịch vụ chất lượng.");
            }
            else if (topPositives.Contains("rẻ"))
            {
                sb.AppendLine("Cực kỳ thích hợp cho các nhóm bạn học sinh, sinh viên hoặc gia đình muốn trải nghiệm dịch vụ chất lượng cao với chi phí tiết kiệm.");
            }
            else if (topPositives.Contains("sang trọng") || topPositives.Contains("tiện nghi"))
            {
                sb.AppendLine("Rất xứng đáng để làm nơi nghỉ ngơi, thư giãn hoặc tiếp khách trang trọng, đẳng cấp.");
            }
            else
            {
                sb.AppendLine("Rất đáng để bạn thêm vào danh sách yêu thích và tự mình trải nghiệm cùng bạn bè!");
            }

            return sb.ToString();
        }
    }
}
