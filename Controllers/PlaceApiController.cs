using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using DACS.Data;
using DACS.Helpers;
using DACS.Models;
using DACS.Repositories;
using DACS.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace DACS.Controllers
{
    [ApiController]
    [Route("api/places")]
    public class PlaceApiController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly IPlaceRepository _repo;
        private readonly PlaceReviewService _reviews;
        private readonly UserManager<IdentityUser> _userManager;

        public PlaceApiController(
            ApplicationDbContext context,
            IPlaceRepository repo,
            PlaceReviewService reviews,
            UserManager<IdentityUser> userManager)
        {
            _context = context;
            _repo = repo;
            _reviews = reviews;
            _userManager = userManager;
        }

        // Endpoint không có [Authorize] chỉ đọc cookie mặc định, nên phải tự đọc JWT cho client mobile
        private async Task<ClaimsPrincipal> GetCurrentUserAsync()
        {
            if (User.Identity?.IsAuthenticated == true) return User;

            var jwt = await HttpContext.AuthenticateAsync(JwtBearerDefaults.AuthenticationScheme);
            return jwt.Succeeded && jwt.Principal != null ? jwt.Principal : User;
        }

        // GET: /api/places/categories
        [HttpGet("categories")]
        public async Task<IActionResult> GetCategories()
        {
            var categories = await _context.PlaceCategories
                .AsNoTracking()
                .Select(c => new
                {
                    c.Id,
                    c.Name,
                    c.Slug,
                    c.Icon
                })
                .ToListAsync();

            return Ok(categories);
        }

        // GET: /api/places?search=xxx&categoryIds=1&categoryIds=2
        [HttpGet]
        public async Task<IActionResult> GetPlaces([FromQuery] string? search, [FromQuery] int[]? categoryIds)
        {
            // Lọc trên danh sách đã cache trong RAM, không phải gọi Supabase mỗi lần tìm kiếm
            IEnumerable<PlaceListItemDto> query = await _repo.GetApprovedListAsync();

            if (!string.IsNullOrWhiteSpace(search))
            {
                var term = search.Trim().ToLower();
                query = query.Where(p =>
                    p.Name.ToLower().Contains(term) ||
                    (p.Address != null && p.Address.ToLower().Contains(term)) ||
                    (p.Description != null && p.Description.ToLower().Contains(term)));
            }

            if (categoryIds != null && categoryIds.Length > 0)
            {
                query = query.Where(p => p.Categories.Any(c => categoryIds.Contains(c.Id)));
            }

            return Ok(query.ToList());
        }

        // GET: /api/places/5
        [HttpGet("{id}")]
        public async Task<IActionResult> GetPlace(int id)
        {
            var place = await _context.Places
                .AsNoTracking()
                .Include(p => p.Categories)
                .Include(p => p.Images)
                .Include(p => p.Comments)
                    .ThenInclude(c => c.User)
                .FirstOrDefaultAsync(p => p.Id == id);

            if (place == null || !PlaceAccess.CanView(place, await GetCurrentUserAsync()))
                return NotFound(new { success = false, message = "Không tìm thấy địa điểm." });

            var result = new
            {
                place.Id,
                place.Name,
                place.Address,
                place.Latitude,
                place.Longitude,
                place.Description,
                place.ImageUrl,
                place.PhoneNumber,
                place.PriceRange,
                place.BannerUrl,
                BannerStatus = (int)place.BannerStatus,
                place.IsApproved,
                place.StarRating,
                place.Amenities,
                place.OpeningHours,
                place.Website,
                place.OwnerId,
                place.AiSummaryCache,
                place.AiSummaryCacheUpdatedAt,
                Categories = place.Categories.Select(c => new
                {
                    c.Id,
                    c.Name,
                    c.Slug,
                    c.Icon
                }).ToList(),
                Images = place.Images.Select(img => new
                {
                    img.Id,
                    img.ImageUrl
                }).ToList(),
                Comments = place.Comments
                    .OrderByDescending(c => c.CreatedAt)
                    .Select(c => new
                    {
                        c.Id,
                        c.Content,
                        c.Rating,
                        c.CreatedAt,
                        c.HelpfulCount,
                        c.UserId,
                        UserEmail = c.User != null ? c.User.Email : "Người dùng ẩn danh"
                    }).ToList()
            };

            return Ok(result);
        }

        // GET: /api/places/5/ai-summary
        [HttpGet("{id}/ai-summary")]
        public async Task<IActionResult> GetAiSummary(int id, [FromQuery] bool forceRefresh = false)
        {
            var place = await _context.Places
                .Include(p => p.Comments)
                .FirstOrDefaultAsync(p => p.Id == id);

            var currentUser = await GetCurrentUserAsync();
            if (place == null || !PlaceAccess.CanView(place, currentUser))
                return NotFound(new { success = false, message = "Không tìm thấy địa điểm." });

            // Chỉ chủ địa điểm và Admin được yêu cầu phân tích lại
            forceRefresh = forceRefresh && PlaceAccess.CanManage(place, currentUser);

            var ai = await _reviews.GetAiSummaryAsync(place, forceRefresh);
            var sentiment = PlaceReviewService.CountSentiment(place.Comments);

            return Ok(new
            {
                success = true,
                summary = ai.Summary,
                isCached = ai.FromCache,
                updatedAt = place.AiSummaryCacheUpdatedAt,
                sentimentStats = new
                {
                    positive = sentiment.Positive,
                    neutral = sentiment.Neutral,
                    negative = sentiment.Negative,
                    total = place.Comments.Count
                }
            });
        }

        public class AddCommentDto
        {
            public string Content { get; set; } = string.Empty;
            public int Rating { get; set; } = 5;
        }

        // POST: /api/places/5/comments
        [Authorize]
        [HttpPost("{id}/comments")]
        public async Task<IActionResult> AddComment(int id, [FromBody] AddCommentDto model)
        {
            if (string.IsNullOrWhiteSpace(model.Content))
                return BadRequest(new { success = false, message = "Nội dung bình luận không được để trống." });

            var place = await _context.Places.FindAsync(id);
            if (place == null || !PlaceAccess.CanView(place, User))
                return NotFound(new { success = false, message = "Địa điểm không tồn tại." });

            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Unauthorized(new { success = false, message = "Vui lòng đăng nhập." });

            var comment = await _reviews.AddCommentAsync(place, userId, model.Content, model.Rating);

            var user = await _userManager.FindByIdAsync(userId);

            return Ok(new
            {
                success = true,
                message = "Gửi bình luận thành công.",
                comment = new
                {
                    comment.Id,
                    comment.Content,
                    comment.Rating,
                    comment.CreatedAt,
                    comment.HelpfulCount,
                    comment.UserId,
                    UserEmail = user?.Email ?? "Người dùng"
                }
            });
        }

        // POST: /api/places/comments/10/helpful
        [Authorize]
        [HttpPost("comments/{commentId}/helpful")]
        public async Task<IActionResult> VoteCommentHelpful(int commentId)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Unauthorized(new { success = false, message = "Vui lòng đăng nhập." });

            var vote = await _reviews.VoteHelpfulAsync(commentId, userId, User);
            return vote.Status switch
            {
                HelpfulVoteStatus.NotFound => NotFound(new { success = false, message = "Không tìm thấy bình luận." }),
                HelpfulVoteStatus.AlreadyVoted => BadRequest(new { success = false, message = "Bạn đã bình chọn bình luận này rồi." }),
                _ => Ok(new { success = true, helpfulCount = vote.HelpfulCount })
            };
        }
    }
}
