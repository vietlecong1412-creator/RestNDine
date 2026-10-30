using System.Security.Claims;
using DACS.Models;

namespace DACS.Helpers
{
    public static class PlaceAccess
    {
        /// <summary>Địa điểm chưa duyệt chỉ chủ địa điểm và Admin được xem.</summary>
        public static bool CanView(Place place, ClaimsPrincipal user) =>
            place.IsApproved || CanManage(place, user);

        /// <summary>Chủ địa điểm hoặc Admin.</summary>
        public static bool CanManage(Place place, ClaimsPrincipal user)
        {
            if (user.IsInRole("Admin"))
                return true;

            var userId = user.FindFirstValue(ClaimTypes.NameIdentifier);
            return !string.IsNullOrEmpty(userId) && place.OwnerId == userId;
        }
    }
}
