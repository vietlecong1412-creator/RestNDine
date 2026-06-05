using System.Net;
using System.Security.Cryptography;
using System.Text;

namespace DACS.Services
{
    /// <summary>
    /// Service tạo URL thanh toán VNPay và xác thực chữ ký callback.
    /// Chuẩn: VNPAY API v2.1.0 - HMAC-SHA512
    /// 
    /// Quy tắc ký:
    ///   - signData = "key1=value1&key2=value2..." (RAW value, KHÔNG URL-encode)
    ///   - queryString = "key1=urlencoded_value1&..." (URL-encode value để gắn vào URL)
    /// </summary>
    public class VnPayService
    {
        private readonly IConfiguration _config;

        public VnPayService(IConfiguration config)
        {
            _config = config;
        }

        // ─────────────────────────────────────────────────────
        // Tạo URL thanh toán
        // ─────────────────────────────────────────────────────
        public string CreatePaymentUrl(HttpContext context, VnPayPaymentRequest model)
        {
            var vnpConfig  = _config.GetSection("VnPay");
            var tmnCode    = vnpConfig["TmnCode"]!;
            var hashSecret = vnpConfig["HashSecret"]!;
            var baseUrl    = vnpConfig["BaseUrl"]!;
            var version    = vnpConfig["Version"]  ?? "2.1.0";
            var command    = vnpConfig["Command"]   ?? "pay";
            var currCode   = vnpConfig["CurrCode"]  ?? "VND";
            var locale     = vnpConfig["Locale"]    ?? "vn";

            // Return URL lấy động từ request
            var returnUrl = $"{context.Request.Scheme}://{context.Request.Host}/Place/VnpayReturn";

            // Tham số bắt buộc sort theo key (alphabet)
            var vnpParams = new SortedDictionary<string, string>(StringComparer.Ordinal)
            {
                { "vnp_Version",    version },
                { "vnp_Command",    command },
                { "vnp_TmnCode",    tmnCode },
                { "vnp_Amount",     ((long)(model.Amount * 100)).ToString() },
                { "vnp_CreateDate", model.CreatedAt.ToString("yyyyMMddHHmmss") },
                { "vnp_CurrCode",   currCode },
                { "vnp_IpAddr",     GetIpAddress(context) },
                { "vnp_Locale",     locale },
                { "vnp_OrderInfo",  model.OrderInfo },
                { "vnp_OrderType",  "other" },
                { "vnp_ReturnUrl",  returnUrl },
                { "vnp_TxnRef",     model.OrderId },
            };

            // ── Build queryString using WebUtility.UrlEncode (VNPAY v2.1.0 standard) ──
            var queryBuilder = new StringBuilder();

            foreach (var kv in vnpParams)
            {
                if (string.IsNullOrEmpty(kv.Value)) continue;

                if (queryBuilder.Length > 0) queryBuilder.Append('&');
                queryBuilder.Append(WebUtility.UrlEncode(kv.Key)).Append('=').Append(WebUtility.UrlEncode(kv.Value));
            }

            var signData   = queryBuilder.ToString();
            var secureHash = HmacSha512(hashSecret, signData);

            System.Console.WriteLine($"[VNPAY SIGN DATA] {signData}");
            System.Console.WriteLine($"[VNPAY SECURE HASH] {secureHash}");

            return $"{baseUrl}?{queryBuilder}&vnp_SecureHash={secureHash}";
        }

        // ─────────────────────────────────────────────────────
        // Xác thực chữ ký callback từ VNPay
        // ─────────────────────────────────────────────────────
        public bool ValidateSignature(IQueryCollection queryParams, out string responseCode)
        {
            var hashSecret = _config["VnPay:HashSecret"]!;
            responseCode   = queryParams["vnp_ResponseCode"].ToString();
            var receivedHash = queryParams["vnp_SecureHash"].ToString();

            // Lấy tất cả tham số trừ vnp_SecureHash, sort
            var sortedParams = new SortedDictionary<string, string>(StringComparer.Ordinal);
            foreach (var key in queryParams.Keys)
            {
                if (key == "vnp_SecureHash" || key == "vnp_SecureHashType") continue;
                sortedParams[key] = queryParams[key].ToString();
            }

            // Build signData từ callback (Sắp xếp và dùng WebUtility.UrlEncode)
            var signBuilder = new StringBuilder();
            foreach (var kv in sortedParams)
            {
                if (string.IsNullOrEmpty(kv.Value)) continue;
                if (signBuilder.Length > 0) signBuilder.Append('&');
                signBuilder.Append(WebUtility.UrlEncode(kv.Key)).Append('=').Append(WebUtility.UrlEncode(kv.Value));
            }

            var computedHash = HmacSha512(hashSecret, signBuilder.ToString());
            return string.Equals(computedHash, receivedHash, StringComparison.OrdinalIgnoreCase);
        }

        // ─────────────────────────────────────────────────────
        // HMAC-SHA512
        // ─────────────────────────────────────────────────────
        private static string HmacSha512(string key, string data)
        {
            using var hmac = new HMACSHA512(Encoding.UTF8.GetBytes(key));
            var hash = hmac.ComputeHash(Encoding.UTF8.GetBytes(data));
            return BitConverter.ToString(hash).Replace("-", "").ToLower();
        }

        // ─────────────────────────────────────────────────────
        // Lấy IP client (127.0.0.1 khi dev local)
        // ─────────────────────────────────────────────────────
        private static string GetIpAddress(HttpContext context)
        {
            var ip = context.Connection.RemoteIpAddress?.ToString() ?? "127.0.0.1";
            return ip == "::1" ? "127.0.0.1" : ip;
        }
    }

    // ─────────────────────────────────────────────────────
    // DTO yêu cầu thanh toán
    // ─────────────────────────────────────────────────────
    public class VnPayPaymentRequest
    {
        public string OrderId    { get; set; } = string.Empty;
        public string OrderInfo  { get; set; } = string.Empty;
        public double Amount     { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.Now;
    }
}
