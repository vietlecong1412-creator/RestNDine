using System.Security.Claims;
using DACS.Data;
using DACS.Helpers;
using DACS.Models;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace DACS.Services
{
    public record SentimentCounts(int Positive, int Neutral, int Negative);

    public record AiSummaryView(string Summary, bool FromCache);

    public enum HelpfulVoteStatus
    {
        Success,
        NotFound,
        AlreadyVoted
    }

    public record HelpfulVoteResult(HelpfulVoteStatus Status, int HelpfulCount = 0);

    /// <summary>
    /// Nghiệp vụ bình luận, vote "Hữu ích" và tóm tắt AI, dùng chung cho web (MVC) và API mobile.
    /// Các controller chỉ còn lo kiểm tra quyền xem địa điểm và định dạng response.
    /// </summary>
    public class PlaceReviewService
    {
        private readonly ApplicationDbContext _context;
        private readonly IAiSummaryService _aiSummaryService;

        public PlaceReviewService(ApplicationDbContext context, IAiSummaryService aiSummaryService)
        {
            _context = context;
            _aiSummaryService = aiSummaryService;
        }

        public static bool IsAiCacheValid(Place place) =>
            !string.IsNullOrEmpty(place.AiSummaryCache)
            && place.AiSummaryCacheUpdatedAt.HasValue
            && (!place.Comments.Any()
                || place.Comments.Max(c => c.CreatedAt) <= place.AiSummaryCacheUpdatedAt.Value);

        public static SentimentCounts CountSentiment(IEnumerable<PlaceComment> comments)
        {
            int positive = 0, neutral = 0, negative = 0;
            foreach (var c in comments)
            {
                if (c.Rating >= 4) positive++;
                else if (c.Rating == 3) neutral++;
                else negative++;
            }
            return new SentimentCounts(positive, neutral, negative);
        }

        /// <param name="place">Place đang được DbContext theo dõi, đã nạp Comments.</param>
        public async Task<AiSummaryView> GetAiSummaryAsync(Place place, bool forceRefresh)
        {
            if (!forceRefresh && IsAiCacheValid(place))
                return new AiSummaryView(place.AiSummaryCache!, true);

            var reviews = place.Comments.Select(c => (c.Content, c.Rating, c.CreatedAt));
            var result = await _aiSummaryService.SummarizeReviewsAsync(place.Name, reviews);

            // Bản dự phòng không lưu vào DB để lần sau còn phân tích lại
            if (result.IsFinal)
            {
                place.AiSummaryCache = result.Summary;
                place.AiSummaryCacheUpdatedAt = DateTime.UtcNow;
                await _context.SaveChangesAsync();
            }

            return new AiSummaryView(result.Summary, false);
        }

        /// <param name="place">Place đang được DbContext theo dõi.</param>
        public async Task<PlaceComment> AddCommentAsync(Place place, string userId, string content, int rating)
        {
            var comment = new PlaceComment
            {
                PlaceId = place.Id,
                Content = content.Trim(),
                Rating = Math.Clamp(rating, 1, 5),
                UserId = userId,
                CreatedAt = DateTime.UtcNow
            };
            _context.PlaceComments.Add(comment);

            // Có bình luận mới thì tóm tắt AI cũ không còn đúng
            place.AiSummaryCache = null;
            place.AiSummaryCacheUpdatedAt = null;

            await _context.SaveChangesAsync();
            return comment;
        }

        public async Task<HelpfulVoteResult> VoteHelpfulAsync(int commentId, string userId, ClaimsPrincipal user)
        {
            var comment = await _context.PlaceComments
                .AsNoTracking()
                .Include(c => c.Place)
                .FirstOrDefaultAsync(c => c.Id == commentId);
            if (comment?.Place == null || !PlaceAccess.CanView(comment.Place, user))
                return new HelpfulVoteResult(HelpfulVoteStatus.NotFound);

            if (await _context.CommentHelpfulVotes.AnyAsync(v => v.CommentId == commentId && v.UserId == userId))
                return new HelpfulVoteResult(HelpfulVoteStatus.AlreadyVoted);

            // Retry chạy lại cả khối, nên phiếu của lần thử trước phải được gỡ khỏi change tracker
            CommentHelpfulVote? vote = null;
            var strategy = _context.Database.CreateExecutionStrategy();
            return await strategy.ExecuteAsync(async () =>
            {
                if (vote != null) _context.Entry(vote).State = EntityState.Detached;

                await using var transaction = await _context.Database.BeginTransactionAsync();

                vote = new CommentHelpfulVote { CommentId = commentId, UserId = userId, VotedAt = DateTime.UtcNow };
                _context.CommentHelpfulVotes.Add(vote);
                try
                {
                    await _context.SaveChangesAsync();
                }
                catch (DbUpdateException ex) when (ex.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
                {
                    // Hai request cùng lúc đều qua bước kiểm tra trên; khóa chính (CommentId, UserId) chặn request sau
                    _context.Entry(vote).State = EntityState.Detached;
                    return new HelpfulVoteResult(HelpfulVoteStatus.AlreadyVoted);
                }

                // Tăng bằng SQL để các vote đồng thời của nhiều người không ghi đè nhau
                await _context.PlaceComments
                    .Where(c => c.Id == commentId)
                    .ExecuteUpdateAsync(s => s.SetProperty(c => c.HelpfulCount, c => c.HelpfulCount + 1));

                var helpfulCount = await _context.PlaceComments
                    .Where(c => c.Id == commentId)
                    .Select(c => c.HelpfulCount)
                    .FirstAsync();

                await transaction.CommitAsync();
                return new HelpfulVoteResult(HelpfulVoteStatus.Success, helpfulCount);
            });
        }
    }
}
