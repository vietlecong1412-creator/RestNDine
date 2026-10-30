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
        private const string ScriptName = "analyze_reviews.py";
        private const int MaxConcurrentRuns = 2;
        private const int MaxReviewsPerRun = 200;
        private const double LowRatingThreshold = 3.5;
        private static readonly TimeSpan QueueWait = TimeSpan.FromSeconds(30);
        private static readonly TimeSpan FallbackCacheTime = TimeSpan.FromMinutes(10);

        // Mỗi lần chạy là một tiến trình Python nạp PhoBERT vào RAM, nên giới hạn trên toàn ứng dụng
        private static readonly SemaphoreSlim RunLimiter = new(MaxConcurrentRuns, MaxConcurrentRuns);

        private readonly IMemoryCache _cache;
        private readonly TimeSpan _runTimeout;
        private readonly ILogger<LocalAiSummaryService> _logger;

        public LocalAiSummaryService(IMemoryCache cache, IConfiguration configuration, ILogger<LocalAiSummaryService> logger)
        {
            _cache = cache;
            _logger = logger;
            _runTimeout = TimeSpan.FromSeconds(configuration.GetValue("AiSummary:TimeoutSeconds", 120));
        }

        public class PythonReport
        {
            public int total_reviews { get; set; }
            public string category { get; set; }
            public Dictionary<string, int> overall_sentiment { get; set; }
            public Dictionary<string, Dictionary<string, int>> aspect_stats { get; set; }
            public Dictionary<string, List<string>> highlights { get; set; }
        }

        public async Task<AiSummaryResult> SummarizeReviewsAsync(string placeName, IEnumerable<(string content, int rating, DateTime createdAt)> reviews)
        {
            var reviewList = reviews?.Where(r => !string.IsNullOrWhiteSpace(r.content)).ToList()
                             ?? new List<(string, int, DateTime)>();
            if (!reviewList.Any())
                return new AiSummaryResult("📍 Chưa có đủ đánh giá từ cộng đồng để AI tiến hành phân tích. Hãy là người đầu tiên chia sẻ cảm nhận của bạn!", true);

            var sortedContents = reviewList.Select(r => r.content).OrderBy(c => c).ToList();
            var cacheKey = $"AiSummary_{placeName}_{string.Join("|", sortedContents).GetHashCode()}";

            if (_cache.TryGetValue(cacheKey, out AiSummaryResult? cached) && cached != null)
                return cached;

            // Tách review 6 tháng gần nhất vs cũ hơn
            var cutoff = DateTime.UtcNow.AddMonths(-6);
            var recentList = reviewList.Where(r => r.createdAt >= cutoff).ToList();
            var oldList    = reviewList.Where(r => r.createdAt < cutoff).ToList();

            // Ưu tiên dùng review gần nhất nếu đủ 3, không thì dùng tất cả
            var primaryList  = recentList.Count >= 3 ? recentList : reviewList;
            string trendNote = BuildTrendNote(recentList, oldList);

            if (!await RunLimiter.WaitAsync(QueueWait))
            {
                // Đang quá tải: trả bản dự phòng nhưng không cache, để lần sau còn chạy AI
                _logger.LogWarning("AI đang quá tải, dùng bản dự phòng cho {PlaceName}.", placeName);
                return new AiSummaryResult(GetRuleBasedFallback(primaryList, trendNote), false);
            }

            string? pythonOutput;
            try
            {
                // Request khác có thể đã phân tích xong trong lúc chờ
                if (_cache.TryGetValue(cacheKey, out cached) && cached != null)
                    return cached;

                pythonOutput = await RunPythonAnalysisAsync(primaryList
                    .OrderByDescending(r => r.createdAt)
                    .Take(MaxReviewsPerRun)
                    .Select(r => r.content)
                    .ToList());
            }
            finally
            {
                RunLimiter.Release();
            }

            if (!string.IsNullOrEmpty(pythonOutput))
            {
                try
                {
                    var report = JsonSerializer.Deserialize<PythonReport>(pythonOutput,
                        new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
                    if (report?.overall_sentiment != null)
                    {
                        var result = new AiSummaryResult(FormatPythonReport(report, trendNote), true);
                        _cache.Set(cacheKey, result, TimeSpan.FromHours(6));
                        return result;
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Không đọc được kết quả JSON từ Python.");
                }
            }

            // AI lỗi hoặc quá hạn: cache ngắn để không chạy lại liên tục một tác vụ đang hỏng
            _logger.LogWarning("Phân tích AI không thành công, dùng bản dự phòng cho {PlaceName}.", placeName);
            var fallback = new AiSummaryResult(GetRuleBasedFallback(primaryList, trendNote), false);
            _cache.Set(cacheKey, fallback, FallbackCacheTime);
            return fallback;
        }

        // Phát hiện xu hướng thay đổi giữa review gần đây và cũ
        private static string BuildTrendNote(
            List<(string content, int rating, DateTime createdAt)> recent,
            List<(string content, int rating, DateTime createdAt)> old)
        {
            if (recent.Count < 3 || old.Count < 3) return string.Empty;

            double recentAvg = recent.Average(r => r.rating);
            double oldAvg    = old.Average(r => r.rating);
            double diff      = recentAvg - oldAvg;

            if (diff >= 1.2)
                return $"Chất lượng có vẻ đã **cải thiện rõ rệt** trong 6 tháng gần đây (⭐ {recentAvg:F1} so với {oldAvg:F1} trước đó).";
            if (diff <= -1.2)
                return $"Một số dấu hiệu cho thấy chất lượng có thể **giảm sút gần đây** (⭐ {recentAvg:F1} so với {oldAvg:F1} trước đó) — nên đọc bình luận mới nhất.";

            return string.Empty;
        }

        private async Task<string?> RunPythonAnalysisAsync(List<string> reviews)
        {
            if (!File.Exists(ScriptName))
            {
                _logger.LogError("Không tìm thấy {Script} trong {Directory}.", ScriptName, Directory.GetCurrentDirectory());
                return null;
            }

            string[] pythonExecutables = { "python", "python3" };
            string jsonInput = JsonSerializer.Serialize(reviews);

            foreach (var pyExec in pythonExecutables)
            {
                using var timeout = new CancellationTokenSource(_runTimeout);
                try
                {
                    var startInfo = new ProcessStartInfo
                    {
                        FileName = pyExec,
                        Arguments = $"{ScriptName} --json",
                        RedirectStandardInput = true,
                        RedirectStandardOutput = true,
                        RedirectStandardError = true,
                        StandardInputEncoding = new UTF8Encoding(false),  // không BOM — Python json.loads bị lỗi nếu có BOM
                        StandardOutputEncoding = new UTF8Encoding(false),
                        UseShellExecute = false,
                        CreateNoWindow = true,
                        WorkingDirectory = Directory.GetCurrentDirectory()
                    };
                    startInfo.Environment["PYTHONIOENCODING"] = "utf-8";
                    startInfo.Environment["PYTHONLEGACYWINDOWSSTDIO"] = "0";

                    using var process = Process.Start(startInfo);
                    if (process == null) continue;

                    // Diệt cả cây tiến trình khi quá hạn; các lệnh đọc/ghi pipe bên dưới sẽ tự thoát
                    using var killOnTimeout = timeout.Token.Register(() => KillProcessTree(process));

                    await using (var writer = process.StandardInput)
                        await writer.WriteAsync(jsonInput);

                    // Đọc stdout và stderr đồng thời để tránh deadlock khi stderr buffer đầy
                    var stdoutTask = process.StandardOutput.ReadToEndAsync();
                    var stderrTask = process.StandardError.ReadToEndAsync();
                    await process.WaitForExitAsync();
                    var jsonOutput  = await stdoutTask;
                    var errorOutput = await stderrTask;

                    if (timeout.IsCancellationRequested)
                    {
                        _logger.LogError("Phân tích AI quá {Seconds:F0} giây, đã dừng tiến trình Python.", _runTimeout.TotalSeconds);
                        return null;
                    }

                    if (process.ExitCode == 0 && !string.IsNullOrWhiteSpace(jsonOutput) && !jsonOutput.Contains("\"error\""))
                        return jsonOutput;

                    // Script báo lỗi qua cả stdout (JSON {"error":...}) lẫn stderr (traceback)
                    _logger.LogError("Python {Executable} lỗi (exit {ExitCode}). stdout: {Output} stderr: {Error}",
                        pyExec, process.ExitCode, jsonOutput, errorOutput);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Không thể thực thi {Executable}.", pyExec);
                    if (timeout.IsCancellationRequested) return null;
                }
            }

            return null;
        }

        private void KillProcessTree(Process process)
        {
            try
            {
                process.Kill(entireProcessTree: true);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Không dừng được tiến trình Python.");
            }
        }

        private string FormatPythonReport(PythonReport report, string trendNote)
        {
            var total = report.total_reviews;
            var sent  = report.overall_sentiment;

            int pos = sent.GetValueOrDefault("positive", 0);
            int neg = sent.GetValueOrDefault("negative", 0);

            double posPct = total > 0 ? pos * 100.0 / total : 0;
            double negPct = total > 0 ? neg * 100.0 / total : 0;

            var sb = new StringBuilder();
            sb.AppendLine($"**Tổng hợp {total} đánh giá gần nhất** · Phân tích bởi PhoBERT AI");
            sb.AppendLine();

            if (!string.IsNullOrEmpty(trendNote))
            {
                sb.AppendLine($"🕐 {trendNote}");
                sb.AppendLine();
            }

            // Nhận định tổng thể — viết tự nhiên theo từng mức
            if (posPct >= 75)
                sb.AppendLine($"Đa phần khách hàng (**{posPct:F0}%**) đều có trải nghiệm tốt tại đây — tín hiệu đáng tin cậy từ cộng đồng.");
            else if (posPct >= 55)
                sb.AppendLine($"Hơn nửa số khách (**{posPct:F0}%**) đánh giá tích cực, tuy vẫn còn **{negPct:F0}%** có phản hồi chưa hài lòng.");
            else if (negPct >= 50)
                sb.AppendLine($"Khá nhiều khách (**{negPct:F0}%**) có trải nghiệm không tốt — nên cân nhắc và đọc kỹ bình luận trước khi quyết định.");
            else
                sb.AppendLine($"Ý kiến khá phân tán: **{posPct:F0}%** tích cực, **{negPct:F0}%** tiêu cực — trải nghiệm có thể khác nhau tùy người.");
            sb.AppendLine();

            // Phân tích từng khía cạnh
            var aspectLines = new List<string>();
            foreach (var asp in report.aspect_stats)
            {
                var stats  = asp.Value;
                int aPos   = stats.GetValueOrDefault("positive", 0);
                int aNeg   = stats.GetValueOrDefault("negative", 0);
                int aTotal = aPos + stats.GetValueOrDefault("neutral", 0) + aNeg;
                if (aTotal < 2) continue;

                double aPosPct = aPos * 100.0 / aTotal;
                double aNegPct = aNeg * 100.0 / aTotal;

                var (icon, name) = asp.Key switch
                {
                    "food_room"      => ("🍽️", "Đồ ăn & Phòng ốc"),
                    "service"        => ("🛎️", "Dịch vụ"),
                    "ambiance_price" => ("✨", "Không gian & Giá cả"),
                    _                => ("📌", asp.Key)
                };

                string verdict = aPosPct >= 70
                    ? $"được đánh giá cao ({aPosPct:F0}% hài lòng)"
                    : aNegPct >= 40
                        ? $"còn một số hạn chế ({aNegPct:F0}% chưa hài lòng)"
                        : $"ở mức ổn định ({aPosPct:F0}% hài lòng)";

                aspectLines.Add($"- {icon} **{name}:** {verdict}");
            }

            if (aspectLines.Any())
            {
                sb.AppendLine("**Chi tiết theo khía cạnh:**");
                foreach (var line in aspectLines) sb.AppendLine(line);
                sb.AppendLine();
            }

            // Trích dẫn tiêu biểu
            var highlights = report.highlights;
            if (highlights != null)
            {
                if (highlights.TryGetValue("positive", out var posH) && posH.Any())
                {
                    sb.AppendLine("💬 **Khách hàng nói gì:**");
                    foreach (var h in posH.Take(2))
                        sb.AppendLine($"> *\"{TruncateHighlight(h)}\"*");
                    sb.AppendLine();
                }
                if (highlights.TryGetValue("negative", out var negH) && negH.Any())
                {
                    sb.AppendLine("⚠️ **Điểm cần lưu ý:**");
                    sb.AppendLine($"> *\"{TruncateHighlight(negH[0])}\"*");
                    sb.AppendLine();
                }
            }

            // Gợi ý cuối
            sb.Append("💡 ");
            if (posPct >= 75)
                sb.AppendLine("**Đáng ghé thử!** Địa điểm này được cộng đồng đánh giá cao một cách nhất quán.");
            else if (negPct >= 40)
                sb.AppendLine("**Nên cân nhắc kỹ** — hãy xem thêm bình luận mới nhất trước khi quyết định.");
            else
                sb.AppendLine("Một lựa chọn ổn — phù hợp nếu địa điểm tiện đường hoặc đúng nhu cầu của bạn.");

            return sb.ToString();
        }

        private string GetRuleBasedFallback(
            List<(string content, int rating, DateTime createdAt)> reviewList,
            string trendNote)
        {
            var positives = new Dictionary<string, (string[] keywords, string label)>
            {
                { "ngon",       (new[] { "ngon", "vừa miệng", "hấp dẫn", "tuyệt vời", "xuất sắc", "đậm đà", "thơm" }, "hương vị thơm ngon") },
                { "rẻ",         (new[] { "rẻ", "hợp lý", "bình dân", "giá tốt", "phải chăng" },                        "giá cả phải chăng") },
                { "đẹp",        (new[] { "đẹp", "view", "xinh", "dễ thương", "chill", "thoáng", "rộng", "phong cách" }, "không gian đẹp") },
                { "thân thiện", (new[] { "thân thiện", "nhiệt tình", "chu đáo", "dễ thương", "vui vẻ", "ân cần" },      "nhân viên thân thiện") },
                { "sạch sẽ",    (new[] { "sạch", "thơm tho", "ngăn nắp", "vệ sinh" },                                   "vệ sinh sạch sẽ") },
                { "nhanh",      (new[] { "nhanh", "liền", "lẹ", "không đợi lâu", "phục vụ nhanh" },                     "phục vụ nhanh chóng") },
                { "sang trọng", (new[] { "sang", "xịn", "đẳng cấp", "cao cấp", "quý phái" },                            "không gian sang trọng") },
                { "tiện nghi",  (new[] { "tiện nghi", "đầy đủ", "hồ bơi", "spa", "gym", "wifi mạnh", "bể bơi" },       "cơ sở vật chất tiện nghi") },
            };

            var negatives = new Dictionary<string, (string[] keywords, string label)>
            {
                { "đợi lâu",         (new[] { "chờ lâu", "đợi lâu", "lâu", "chậm" },         "thời gian chờ hơi lâu") },
                { "giá hơi cao",     (new[] { "đắt", "mắc", "giá cao", "hơi chát" },           "giá cả hơi cao") },
                { "hơi ồn",          (new[] { "ồn", "náo nhiệt", "đông đúc" },                  "không gian hơi ồn") },
                { "hơi chật",        (new[] { "chật", "nhỏ", "hẹp" },                           "diện tích hơi chật") },
                { "wifi yếu",        (new[] { "wifi yếu", "mạng yếu", "mạng chập chờn" },      "kết nối WiFi chưa ổn định") },
                { "nóng bức",        (new[] { "nóng", "bí", "ngột ngạt" },                      "không khí hơi nóng bức") },
                { "thái độ phục vụ", (new[] { "thái độ", "phục vụ kém", "khó chịu" },          "thái độ phục vụ chưa tốt") },
            };

            var posCounts = positives.Keys.ToDictionary(k => k, _ => 0);
            var negCounts = negatives.Keys.ToDictionary(k => k, _ => 0);

            foreach (var r in reviewList)
            {
                var lower = r.content.ToLower();
                foreach (var kvp in positives)
                    if (kvp.Value.keywords.Any(kw => lower.Contains(kw))) posCounts[kvp.Key]++;
                foreach (var kvp in negatives)
                    if (kvp.Value.keywords.Any(kw => lower.Contains(kw))) negCounts[kvp.Key]++;
            }

            double avgRating = reviewList.Average(r => r.rating);
            var topPos = posCounts.Where(x => x.Value > 0).OrderByDescending(x => x.Value).Take(3).ToList();
            var topNeg = negCounts.Where(x => x.Value > 0).OrderByDescending(x => x.Value).Take(2).ToList();

            var sb = new StringBuilder();
            sb.AppendLine("ℹ️ **Bản tóm tắt đơn giản** dựa trên từ khoá — phân tích AI hiện chưa khả dụng.");
            sb.AppendLine();
            sb.AppendLine($"**Tổng hợp {reviewList.Count} đánh giá** · Điểm trung bình: {avgRating:F1}/5 ⭐");
            sb.AppendLine();

            if (!string.IsNullOrEmpty(trendNote))
            {
                sb.AppendLine($"🕐 {trendNote}");
                sb.AppendLine();
            }

            if (topPos.Any())
            {
                var labels = topPos.Select(k => $"**{positives[k.Key].label}**").ToList();
                string joined = labels.Count == 1 ? labels[0]
                              : string.Join(", ", labels.Take(labels.Count - 1)) + " và " + labels.Last();
                // Từ khoá không phân biệt được khen hay chê nên chỉ nói "có nhắc tới"
                sb.AppendLine($"💬 **Được nhắc tới:** Bình luận có đề cập đến {joined}.");
            }
            sb.AppendLine();

            if (topNeg.Any())
            {
                var labels = topNeg.Select(k => $"**{negatives[k.Key].label}**").ToList();
                string joined = labels.Count == 1 ? labels[0] : string.Join(" và ", labels);
                sb.AppendLine($"⚠️ **Lưu ý:** Một số khách phản hồi về {joined}.");
            }
            else if (avgRating >= LowRatingThreshold)
            {
                sb.AppendLine("⚠️ **Lưu ý:** Chưa ghi nhận phản hồi tiêu cực đáng kể.");
            }
            sb.AppendLine();

            sb.Append("💡 ");
            if (avgRating < LowRatingThreshold)
                sb.AppendLine("Đánh giá còn trái chiều — nên đọc thêm bình luận trước khi quyết định.");
            else if (topPos.Any(k => k.Key == "ngon") && topPos.Any(k => k.Key == "rẻ"))
                sb.AppendLine("Vừa ngon vừa rẻ — lý tưởng cho buổi hẹn bạn bè hay gia đình.");
            else if (topPos.Any(k => k.Key is "sang trọng" or "tiện nghi"))
                sb.AppendLine("Lựa chọn lý tưởng cho những dịp cần sự sang trọng và đẳng cấp.");
            else if (topPos.Any(k => k.Key == "đẹp"))
                sb.AppendLine("Điểm đến lý tưởng để check-in và tận hưởng không gian cùng người thân.");
            else if (avgRating >= 4.0)
                sb.AppendLine("Đáng ghé thử — được cộng đồng đánh giá khá cao.");
            else
                sb.AppendLine("Một lựa chọn ổn — hãy ghé thăm và tự mình cảm nhận.");

            return sb.ToString();
        }

        private static string TruncateHighlight(string text, int maxLen = 120)
            => text.Length <= maxLen ? text : text[..maxLen].TrimEnd() + "…";
    }
}
