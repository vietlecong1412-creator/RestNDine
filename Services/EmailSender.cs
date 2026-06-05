using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Identity.UI.Services;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using System;
using System.IO;
using System.Net;
using System.Net.Mail;
using System.Threading.Tasks;

namespace DACS.Services
{
    public class EmailSender : IEmailSender
    {
        private readonly ILogger<EmailSender> _logger;
        private readonly IConfiguration _configuration;
        private readonly IWebHostEnvironment _env;

        public EmailSender(ILogger<EmailSender> logger, IConfiguration configuration, IWebHostEnvironment env)
        {
            _logger = logger;
            _configuration = configuration;
            _env = env;
        }

        public Task SendEmailAsync(string email, string subject, string htmlMessage)
        {
            _ = Task.Run(async () =>
            {
                try
                {
                    var smtpSettings = _configuration.GetSection("SmtpSettings");
                    var host = smtpSettings["Host"];

                    if (string.IsNullOrEmpty(host))
                    {
                        _logger.LogWarning("SMTP Host chưa được cấu hình. Lưu email thành file HTML.");
                        await WriteEmailToLocalHtmlAsync(email, subject, htmlMessage);
                        return;
                    }

                    try
                    {
                        var port = int.Parse(smtpSettings["Port"] ?? "587");
                        var username = smtpSettings["Username"];
                        var password = smtpSettings["Password"];
                        var from = smtpSettings["FromAddress"] ?? "no-reply@restndine.com";
                        var enableSsl = bool.Parse(smtpSettings["EnableSsl"] ?? "true");

                        using var client = new SmtpClient(host, port);
                        client.UseDefaultCredentials = false;
                        client.Credentials = new NetworkCredential(username, password);
                        client.EnableSsl = enableSsl;

                        var mailMessage = new MailMessage
                        {
                            From = new MailAddress(from, "RestNDine Security"),
                            Subject = subject,
                            Body = htmlMessage,
                            IsBodyHtml = true,
                        };
                        mailMessage.To.Add(email);

                        await client.SendMailAsync(mailMessage).WaitAsync(TimeSpan.FromSeconds(15));
                        _logger.LogInformation("Gửi email thành công tới {Email} qua SMTP.", email);
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, "Gửi email tới {Email} qua SMTP thất bại: {Message}", email, ex.Message);
                        await WriteEmailToLocalHtmlAsync(email, subject, htmlMessage);
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Lỗi nghiêm trọng trong EmailSender khi gửi tới {Email}: {Message}", email, ex.Message);
                }
            });

            return Task.CompletedTask;
        }

        private async Task WriteEmailToLocalHtmlAsync(string email, string subject, string htmlMessage)
        {
            var emailDir = Path.Combine(_env.WebRootPath, "sent_emails");
            if (!Directory.Exists(emailDir))
            {
                Directory.CreateDirectory(emailDir);
            }

            var fileName = $"email-{Guid.NewGuid()}.html";
            var filePath = Path.Combine(emailDir, fileName);

            var content = $@"<!DOCTYPE html>
<html lang=""vi"">
<head>
    <meta charset=""utf-8"" />
    <title>{subject}</title>
    <style>
        body {{ font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; padding: 20px; background-color: #f8f9fa; color: #333; }}
        .container {{ max-width: 600px; margin: 0 auto; background: white; padding: 30px; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.05); }}
        .header {{ border-bottom: 2px solid #ff4757; padding-bottom: 15px; margin-bottom: 20px; }}
        .header h2 {{ margin: 0; color: #ff4757; }}
        .info {{ background: #f1f2f6; padding: 12px; border-radius: 6px; margin-bottom: 20px; font-size: 14px; }}
        .info p {{ margin: 5px 0; }}
        .content {{ line-height: 1.6; font-size: 16px; }}
        .footer {{ margin-top: 30px; border-top: 1px solid #e4e7eb; padding-top: 15px; font-size: 12px; color: #7f8c8d; text-align: center; }}
    </style>
</head>
<body>
    <div class=""container"">
        <div class=""header"">
            <h2>RestNDine Security Service</h2>
        </div>
        <div class=""info"">
            <p><strong>Người nhận (To):</strong> {email}</p>
            <p><strong>Tiêu đề (Subject):</strong> {subject}</p>
            <p><strong>Thời gian (Sent At):</strong> {DateTime.Now:dd/MM/yyyy HH:mm:ss}</p>
        </div>
        <div class=""content"">
            {htmlMessage}
        </div>
        <div class=""footer"">
            Đây là email giả lập trong môi trường phát triển (Development) của RestNDine.
        </div>
    </div>
</body>
</html>";

            await File.WriteAllTextAsync(filePath, content);
            _logger.LogInformation($"[EMAIL SIMULATOR] Email gửi tới {email} đã được lưu thành tệp HTML tại: /sent_emails/{fileName}");
        }
    }
}
