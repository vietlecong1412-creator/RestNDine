using System;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace DACS.Services
{
    /// <param name="Summary">Nội dung tóm tắt.</param>
    /// <param name="IsFinal">
    /// false nếu đây là bản dự phòng (AI lỗi, quá hạn hoặc đang quá tải): không lưu vào DB để lần sau còn phân tích lại.
    /// </param>
    public record AiSummaryResult(string Summary, bool IsFinal);

    public interface IAiSummaryService
    {
        Task<AiSummaryResult> SummarizeReviewsAsync(string placeName, IEnumerable<(string content, int rating, DateTime createdAt)> reviews);
    }
}
