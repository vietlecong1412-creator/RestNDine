using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using DACS.Data;
using DACS.Models;
using DACS.Hubs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace DACS.Controllers
{
    [Authorize]
    [Route("api/chat")]
    [ApiController]
    public class ChatController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly UserManager<IdentityUser> _userManager;
        private readonly IHubContext<ChatHub> _hubContext;

        public ChatController(
            ApplicationDbContext context,
            UserManager<IdentityUser> userManager,
            IHubContext<ChatHub> hubContext)
        {
            _context = context;
            _userManager = userManager;
            _hubContext = hubContext;
        }

        // GET: /api/chat/messages?placeId=5&customerId=xxx
        [HttpGet("messages")]
        public async Task<IActionResult> GetMessages([FromQuery] int placeId, [FromQuery] string? customerId)
        {
            var currentUserId = _userManager.GetUserId(User);
            if (string.IsNullOrEmpty(currentUserId)) return Unauthorized();

            var place = await _context.Places.FindAsync(placeId);
            if (place == null) return NotFound("Địa điểm không tồn tại.");

            string ownerId = place.OwnerId ?? string.Empty;
            if (string.IsNullOrEmpty(ownerId))
            {
                return BadRequest("Địa điểm này chưa có chủ quán đăng ký quản lý.");
            }

            bool isOwner = currentUserId == ownerId || User.IsInRole("Admin");
            string targetCustomerId;

            if (isOwner)
            {
                if (string.IsNullOrEmpty(customerId))
                {
                    return BadRequest("Chủ quán cần truyền customerId để xem tin nhắn.");
                }
                targetCustomerId = customerId;
            }
            else
            {
                targetCustomerId = currentUserId;
            }

            // Lấy tin nhắn giữa customer và owner liên quan đến place này
            var messages = await _context.ChatMessages
                .Where(m => m.PlaceId == placeId &&
                            ((m.SenderId == targetCustomerId && m.ReceiverId == ownerId) ||
                             (m.SenderId == ownerId && m.ReceiverId == targetCustomerId)))
                .OrderBy(m => m.SentAt)
                .Select(m => new
                {
                    m.Id,
                    m.SenderId,
                    SenderEmail = m.Sender != null ? m.Sender.Email : "Ẩn danh",
                    m.ReceiverId,
                    ReceiverEmail = m.Receiver != null ? m.Receiver.Email : "Ẩn danh",
                    m.Content,
                    SentAt = m.SentAt.AddHours(7).ToString("dd/MM/yyyy HH:mm"), // Format giờ Việt Nam (UTC+7)
                    m.IsRead
                })
                .ToListAsync();

            return Ok(new { success = true, messages });
        }

        // POST: /api/chat/send
        [HttpPost("send")]
        public async Task<IActionResult> SendMessage([FromForm] int placeId, [FromForm] string receiverId, [FromForm] string content)
        {
            var senderId = _userManager.GetUserId(User);
            if (string.IsNullOrEmpty(senderId)) return Unauthorized();

            if (string.IsNullOrWhiteSpace(content))
            {
                return BadRequest("Nội dung tin nhắn không được để trống.");
            }

            var place = await _context.Places.FindAsync(placeId);
            if (place == null) return NotFound("Địa điểm không tồn tại.");

            // Kiểm tra tính hợp lệ của người nhận
            var receiver = await _userManager.FindByIdAsync(receiverId);
            if (receiver == null) return NotFound("Người nhận không tồn tại.");

            var message = new ChatMessage
            {
                PlaceId = placeId,
                SenderId = senderId,
                ReceiverId = receiverId,
                Content = content.Trim(),
                SentAt = DateTime.UtcNow,
                IsRead = false
            };

            _context.ChatMessages.Add(message);
            await _context.SaveChangesAsync();

            // Lấy email người gửi để gửi realtime qua SignalR
            var senderUser = await _userManager.FindByIdAsync(senderId);
            var senderEmail = senderUser?.Email ?? "Ẩn danh";

            var payload = new
            {
                id = message.Id,
                placeId = message.PlaceId,
                senderId = message.SenderId,
                senderEmail,
                receiverId = message.ReceiverId,
                content = message.Content,
                sentAt = message.SentAt.AddHours(7).ToString("dd/MM/yyyy HH:mm"),
                isRead = message.IsRead
            };

            // Gửi qua SignalR cho cả 2 để đồng bộ thời gian thực
            await _hubContext.Clients.User(receiverId).SendAsync("ReceiveMessage", payload);
            await _hubContext.Clients.User(senderId).SendAsync("ReceiveMessage", payload);

            return Ok(new { success = true, message = payload });
        }

        // GET: /api/chat/conversations?placeId=5
        [HttpGet("conversations")]
        public async Task<IActionResult> GetConversations([FromQuery] int placeId)
        {
            var currentUserId = _userManager.GetUserId(User);
            if (string.IsNullOrEmpty(currentUserId)) return Unauthorized();

            var place = await _context.Places.FindAsync(placeId);
            if (place == null) return NotFound("Địa điểm không tồn tại.");

            string ownerId = place.OwnerId ?? string.Empty;
            if (string.IsNullOrEmpty(ownerId)) return BadRequest("Địa điểm chưa có chủ quán.");

            // Chỉ chủ quán hoặc Admin mới xem được danh sách hội thoại của quán
            if (currentUserId != ownerId && !User.IsInRole("Admin"))
            {
                return Forbid("Bạn không có quyền truy cập danh sách hội thoại của quán này.");
            }

            // Truy vấn tin nhắn trong DB
            var dbMessages = await _context.ChatMessages
                .Where(m => m.PlaceId == placeId)
                .Include(m => m.Sender)
                .Include(m => m.Receiver)
                .ToListAsync();

            // Nhóm cục bộ theo Customer ID (ID không phải là Owner)
            var conversations = dbMessages
                .GroupBy(m => m.SenderId == ownerId ? m.ReceiverId : m.SenderId)
                .Select(g =>
                {
                    var customerId = g.Key;
                    var lastMsg = g.OrderByDescending(m => m.SentAt).First();
                    var customerUser = lastMsg.SenderId == ownerId ? lastMsg.Receiver : lastMsg.Sender;
                    var unread = g.Count(m => m.ReceiverId == ownerId && !m.IsRead);

                    return new
                    {
                        customerId,
                        customerEmail = customerUser?.Email ?? "Ẩn danh",
                        lastMessageContent = lastMsg.Content,
                        lastMessageTimeRaw = lastMsg.SentAt,
                        lastMessageTime = lastMsg.SentAt.AddHours(7).ToString("dd/MM HH:mm"),
                        unreadCount = unread
                    };
                })
                .OrderByDescending(c => c.lastMessageTimeRaw)
                .ToList();

            return Ok(new { success = true, conversations });
        }

        // POST: /api/chat/read
        [HttpPost("read")]
        public async Task<IActionResult> MarkAsRead([FromForm] int placeId, [FromForm] string customerId)
        {
            var currentUserId = _userManager.GetUserId(User);
            if (string.IsNullOrEmpty(currentUserId)) return Unauthorized();

            var place = await _context.Places.FindAsync(placeId);
            if (place == null) return NotFound("Địa điểm không tồn tại.");

            string ownerId = place.OwnerId ?? string.Empty;
            if (string.IsNullOrEmpty(ownerId)) return BadRequest("Địa điểm chưa có chủ quán.");

            bool isOwner = currentUserId == ownerId || User.IsInRole("Admin");

            // Cập nhật trạng thái các tin nhắn gửi đến người dùng hiện tại là Đã đọc (IsRead = true)
            IQueryable<ChatMessage> query;
            if (isOwner)
            {
                // Tin nhắn từ khách hàng gửi tới chủ quán
                query = _context.ChatMessages
                    .Where(m => m.PlaceId == placeId && m.SenderId == customerId && m.ReceiverId == ownerId && !m.IsRead);
            }
            else
            {
                // Tin nhắn từ chủ quán gửi tới khách hàng
                query = _context.ChatMessages
                    .Where(m => m.PlaceId == placeId && m.SenderId == ownerId && m.ReceiverId == currentUserId && !m.IsRead);
            }

            var unreadMessages = await query.ToListAsync();
            if (unreadMessages.Any())
            {
                foreach (var msg in unreadMessages)
                {
                    msg.IsRead = true;
                }
                await _context.SaveChangesAsync();
            }

            return Ok(new { success = true });
        }
    }
}
