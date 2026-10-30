using System.Text;

namespace DACS.Helpers
{
    /// <summary>
    /// Kiểm tra và lưu ảnh upload vào wwwroot/images/{folder}.
    /// Định dạng được xác định bằng magic bytes (không tin đuôi file / Content-Type từ client),
    /// chỉ chấp nhận JPEG, PNG, GIF, WebP, AVIF — SVG/HTML bị loại vì có thể chứa script.
    /// File được lưu với tên GUID và đuôi theo định dạng thật.
    /// </summary>
    public static class ImageUpload
    {
        public const long MaxBytes = 5 * 1024 * 1024; // 5 MB

        public const string AcceptAttribute = "image/jpeg,image/png,image/gif,image/webp,image/avif";

        /// <summary>Trả về thông báo lỗi, hoặc null nếu file là ảnh hợp lệ.</summary>
        public static async Task<string?> ValidateAsync(IFormFile? file)
        {
            if (file == null || file.Length == 0)
                return "Vui lòng chọn file ảnh.";
            if (file.Length > MaxBytes)
                return $"Ảnh vượt quá dung lượng cho phép ({MaxBytes / 1024 / 1024} MB).";
            if (await DetectExtensionAsync(file) == null)
                return "File không phải ảnh hợp lệ. Chỉ chấp nhận JPG, PNG, GIF, WebP, AVIF.";
            return null;
        }

        /// <summary>
        /// Lưu ảnh đã được kiểm tra bằng <see cref="ValidateAsync"/> và trả về URL tương đối (vd: /images/places/abc.jpg).
        /// </summary>
        public static async Task<string> SaveAsync(IFormFile file, string folder)
        {
            var ext = await DetectExtensionAsync(file)
                ?? throw new InvalidOperationException("File ảnh chưa được kiểm tra hợp lệ.");

            var dir = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "images", folder);
            Directory.CreateDirectory(dir);

            var fileName = Guid.NewGuid().ToString() + ext;
            using (var stream = new FileStream(Path.Combine(dir, fileName), FileMode.CreateNew))
                await file.CopyToAsync(stream);

            return $"/images/{folder}/{fileName}";
        }

        /// <summary>Xóa ảnh theo URL tương đối; bỏ qua URL ngoài /images/ và lỗi hệ thống file.</summary>
        public static void TryDelete(string? url)
        {
            if (string.IsNullOrEmpty(url) || !url.StartsWith("/images/") || url.Contains(".."))
                return;

            try
            {
                var path = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", url.TrimStart('/'));
                if (File.Exists(path)) File.Delete(path);
            }
            catch (IOException) { }
            catch (UnauthorizedAccessException) { }
        }

        private static async Task<string?> DetectExtensionAsync(IFormFile file)
        {
            var header = new byte[16];
            int read;
            using (var stream = file.OpenReadStream())
                read = await stream.ReadAtLeastAsync(header, header.Length, throwOnEndOfStream: false);

            if (read >= 3 && header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF)
                return ".jpg";
            if (read >= 8 && header.AsSpan(0, 8).SequenceEqual(new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A }))
                return ".png";

            var ascii = Encoding.ASCII.GetString(header, 0, read);
            if (ascii.StartsWith("GIF87a") || ascii.StartsWith("GIF89a"))
                return ".gif";
            if (read >= 12 && ascii.StartsWith("RIFF") && ascii.Substring(8, 4) == "WEBP")
                return ".webp";
            if (read >= 12 && ascii.Substring(4, 4) == "ftyp" && (ascii.Substring(8, 4) == "avif" || ascii.Substring(8, 4) == "avis"))
                return ".avif";

            return null;
        }
    }
}
