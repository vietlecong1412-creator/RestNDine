using System;

namespace DACS.Services
{
    public static class EmailTemplateHelper
    {
        public static string GetConfirmEmailHtml(string confirmUrl, string email)
        {
            return $@"<!DOCTYPE html>
<html lang=""vi"">
<head>
    <meta charset=""utf-8"">
    <meta name=""viewport"" content=""width=device-width, initial-scale=1.0"">
    <title>Xác nhận tài khoản FoodRadar</title>
</head>
<body style=""margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f6f9; color: #333333;"">
    <table align=""center"" border=""0"" cellpadding=""0"" cellspacing=""0"" width=""100%"" style=""max-width: 600px; margin: 30px auto; background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.06);"">
        <!-- Header -->
        <tr>
            <td align=""center"" style=""padding: 40px 0 30px 0; background: linear-gradient(135deg, #f97316 0%, #ea580c 100%);"">
                <span style=""font-size: 3.5rem; display: block; margin-bottom: 10px;"">📡</span>
                <h1 style=""margin: 0; color: #ffffff; font-size: 32px; font-weight: 800; letter-spacing: -0.5px;"">FoodRadar</h1>
                <p style=""margin: 5px 0 0 0; color: rgba(255,255,255,0.85); font-size: 14px; font-weight: 500;"">Bản đồ ẩm thực & Khách sạn trực quan</p>
            </td>
        </tr>
        
        <!-- Content -->
        <tr>
            <td style=""padding: 40px 30px;"">
                <h2 style=""margin-top: 0; color: #1e293b; font-size: 22px; font-weight: 700; text-align: center;"">Xác thực tài khoản của bạn</h2>
                <p style=""color: #64748b; font-size: 15px; line-height: 1.6; text-align: center; margin-bottom: 30px;"">
                    Chào mừng bạn đến với cộng đồng người yêu ẩm thực! Bạn vừa đăng ký tài khoản tại FoodRadar bằng email <strong>{email}</strong>. Vui lòng bấm vào nút bên dưới để kích hoạt tài khoản ngay lập tức.
                </p>
                
                <!-- Action Button -->
                <table align=""center"" border=""0"" cellpadding=""0"" cellspacing=""0"">
                    <tr>
                        <td align=""center"" style=""border-radius: 50px; background: linear-gradient(135deg, #f97316 0%, #ea580c 100%);"">
                            <a href=""{confirmUrl}"" target=""_blank"" style=""display: inline-block; padding: 14px 40px; font-size: 16px; font-weight: 700; color: #ffffff; text-decoration: none; border-radius: 50px; letter-spacing: 0.5px;"">
                                Kích hoạt tài khoản ngay ⚡
                            </a>
                        </td>
                    </tr>
                </table>
                
                <p style=""color: #94a3b8; font-size: 13px; line-height: 1.5; text-align: center; margin-top: 35px; margin-bottom: 0;"">
                    Nếu nút trên không hoạt động, bạn có thể copy và dán liên kết sau vào trình duyệt:<br>
                    <a href=""{confirmUrl}"" style=""color: #f97316; word-break: break-all;"">{confirmUrl}</a>
                </p>
            </td>
        </tr>
        
        <!-- Footer -->
        <tr>
            <td style=""padding: 25px 30px; background-color: #f8fafc; border-top: 1px solid #f1f5f9; text-align: center; color: #94a3b8; font-size: 12px; line-height: 1.5;"">
                <p style=""margin: 0 0 8px 0;"">Email này được gửi tự động từ hệ thống bảo mật FoodRadar.</p>
                <p style=""margin: 0;"">Nếu bạn không thực hiện đăng ký này, vui lòng bỏ qua email hoặc liên hệ với bộ phận hỗ trợ của chúng tôi.</p>
                <p style=""margin: 15px 0 0 0; font-weight: bold; color: #64748b;"">📡 FoodRadar &copy; 2026</p>
            </td>
        </tr>
    </table>
</body>
</html>";
        }

        public static string GetResetPasswordHtml(string resetUrl, string email)
        {
            return $@"<!DOCTYPE html>
<html lang=""vi"">
<head>
    <meta charset=""utf-8"">
    <meta name=""viewport"" content=""width=device-width, initial-scale=1.0"">
    <title>Đặt lại mật khẩu FoodRadar</title>
</head>
<body style=""margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f6f9; color: #333333;"">
    <table align=""center"" border=""0"" cellpadding=""0"" cellspacing=""0"" width=""100%"" style=""max-width: 600px; margin: 30px auto; background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.06);"">
        <!-- Header -->
        <tr>
            <td align=""center"" style=""padding: 40px 0 30px 0; background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);"">
                <span style=""font-size: 3.5rem; display: block; margin-bottom: 10px;"">🔐</span>
                <h1 style=""margin: 0; color: #ffffff; font-size: 32px; font-weight: 800; letter-spacing: -0.5px;"">FoodRadar Security</h1>
                <p style=""margin: 5px 0 0 0; color: rgba(255,255,255,0.85); font-size: 14px; font-weight: 500;"">Yêu cầu thay đổi mật khẩu</p>
            </td>
        </tr>
        
        <!-- Content -->
        <tr>
            <td style=""padding: 40px 30px;"">
                <h2 style=""margin-top: 0; color: #1e293b; font-size: 22px; font-weight: 700; text-align: center;"">Yêu cầu đặt lại mật khẩu</h2>
                <p style=""color: #64748b; font-size: 15px; line-height: 1.6; text-align: center; margin-bottom: 30px;"">
                    Chúng tôi nhận được yêu cầu khôi phục mật khẩu cho tài khoản FoodRadar liên kết với email <strong>{email}</strong>. Vui lòng bấm vào nút bên dưới để thiết lập mật khẩu mới ngay lập tức.
                </p>
                
                <!-- Action Button -->
                <table align=""center"" border=""0"" cellpadding=""0"" cellspacing=""0"">
                    <tr>
                        <td align=""center"" style=""border-radius: 50px; background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);"">
                            <a href=""{resetUrl}"" target=""_blank"" style=""display: inline-block; padding: 14px 40px; font-size: 16px; font-weight: 700; color: #ffffff; text-decoration: none; border-radius: 50px; letter-spacing: 0.5px;"">
                                Đặt lại mật khẩu mới
                            </a>
                        </td>
                    </tr>
                </table>
                
                <p style=""color: #ef4444; font-size: 13px; font-weight: 600; text-align: center; margin-top: 25px; margin-bottom: 10px;"">
                    ⚠️ Lưu ý: Liên kết này chỉ có hiệu lực trong vòng 2 giờ!
                </p>
                
                <p style=""color: #94a3b8; font-size: 13px; line-height: 1.5; text-align: center; margin-top: 25px; margin-bottom: 0;"">
                    Nếu nút trên không hoạt động, bạn có thể copy và dán liên kết sau vào trình duyệt:<br>
                    <a href=""{resetUrl}"" style=""color: #ef4444; word-break: break-all;"">{resetUrl}</a>
                </p>
            </td>
        </tr>
        
        <!-- Footer -->
        <tr>
            <td style=""padding: 25px 30px; background-color: #f8fafc; border-top: 1px solid #f1f5f9; text-align: center; color: #94a3b8; font-size: 12px; line-height: 1.5;"">
                <p style=""margin: 0 0 8px 0;"">Email này được gửi tự động từ hệ thống bảo mật FoodRadar.</p>
                <p style=""margin: 0;"">Nếu bạn không thực hiện yêu cầu này, tài khoản của bạn vẫn an toàn và bạn có thể bỏ qua email này.</p>
                <p style=""margin: 15px 0 0 0; font-weight: bold; color: #64748b;"">📡 FoodRadar &copy; 2026</p>
            </td>
        </tr>
    </table>
</body>
</html>";
        }

        public static string GetOtpEmailHtml(string otpCode, string email)
        {
            return $@"<!DOCTYPE html>
<html lang=""vi"">
<head>
    <meta charset=""utf-8"">
    <meta name=""viewport"" content=""width=device-width, initial-scale=1.0"">
    <title>Mã xác thực OTP FoodRadar</title>
</head>
<body style=""margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f6f9; color: #333333;"">
    <table align=""center"" border=""0"" cellpadding=""0"" cellspacing=""0"" width=""100%"" style=""max-width: 600px; margin: 30px auto; background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.06);"">
        <!-- Header -->
        <tr>
            <td align=""center"" style=""padding: 40px 0 30px 0; background: linear-gradient(135deg, #f97316 0%, #ea580c 100%);"">
                <span style=""font-size: 3.5rem; display: block; margin-bottom: 10px;"">📡</span>
                <h1 style=""margin: 0; color: #ffffff; font-size: 32px; font-weight: 800; letter-spacing: -0.5px;"">FoodRadar</h1>
                <p style=""margin: 5px 0 0 0; color: rgba(255,255,255,0.85); font-size: 14px; font-weight: 500;"">Bản đồ ẩm thực & Khách sạn trực quan</p>
            </td>
        </tr>
        
        <!-- Content -->
        <tr>
            <td style=""padding: 40px 30px;"">
                <h2 style=""margin-top: 0; color: #1e293b; font-size: 22px; font-weight: 700; text-align: center;"">Mã xác thực OTP của bạn</h2>
                <p style=""color: #64748b; font-size: 15px; line-height: 1.6; text-align: center; margin-bottom: 25px;"">
                    Chào mừng bạn đến với FoodRadar! Bạn vừa đăng ký tài khoản mới bằng email <strong>{email}</strong>. Vui lòng sử dụng mã xác thực OTP gồm 6 chữ số dưới đây để kích hoạt tài khoản của mình.
                </p>
                
                <!-- OTP Code Display -->
                <table align=""center"" border=""0"" cellpadding=""0"" cellspacing=""0"" style=""width: 100%; max-width: 280px; margin: 0 auto;"">
                    <tr>
                        <td align=""center"" style=""background-color: #f8fafc; border: 2px dashed #cbd5e1; border-radius: 12px; padding: 18px 0;"">
                            <span style=""font-size: 36px; font-weight: 800; letter-spacing: 8px; color: #f97316; font-family: 'Courier New', Courier, monospace; display: inline-block; padding-left: 8px;"">{otpCode}</span>
                        </td>
                    </tr>
                </table>
                
                <p style=""color: #ef4444; font-size: 13px; font-weight: 600; text-align: center; margin-top: 25px; margin-bottom: 10px;"">
                    ⚠️ Lưu ý: Mã xác thực này chỉ có hiệu lực trong vòng 10 phút!
                </p>
            </td>
        </tr>
        
        <!-- Footer -->
        <tr>
            <td style=""padding: 25px 30px; background-color: #f8fafc; border-top: 1px solid #f1f5f9; text-align: center; color: #94a3b8; font-size: 12px; line-height: 1.5;"">
                <p style=""margin: 0 0 8px 0;"">Email này được gửi tự động từ hệ thống bảo mật FoodRadar.</p>
                <p style=""margin: 0;"">Nếu bạn không thực hiện đăng ký này, vui lòng bỏ qua email hoặc liên hệ với bộ phận hỗ trợ của chúng tôi.</p>
                <p style=""margin: 15px 0 0 0; font-weight: bold; color: #64748b;"">📡 FoodRadar &copy; 2026</p>
            </td>
        </tr>
    </table>
</body>
</html>";
        }
    }
}
