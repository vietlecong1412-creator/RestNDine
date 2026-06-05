using Microsoft.AspNetCore.SignalR;
using Microsoft.AspNetCore.Authorization;

namespace DACS.Hubs
{
    [Authorize]
    public class ChatHub : Hub
    {
        // Hub này đóng vai trò làm kênh kết nối thời gian thực.
        // SignalR tự động dùng ClaimTypes.NameIdentifier làm Context.UserIdentifier.
    }
}
