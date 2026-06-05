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
                    await SendViaSmtpAsync(email, subject, htmlMessage);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Lỗi nghiêm trọng trong EmailSender khi gửi tới {Email}", email);
                    await WriteEmailToLocalHtmlAsync(email, subject, htmlMessage);
                }
            });

            return Task.CompletedTask;
        }

        private async Task SendViaSmtpAsync(string email, string subject, string htmlMessage)
        {
            var smtpSettings = _configuration.GetSection("SmtpSettings");
            var host = smtpSettings["Host"];
            var port = int.Parse(smtpSettings["Port"] ?? "587");
            var username = smtpSettings["Username"];
            var password = smtpSettings["Password"];
            var from = smtpSettings["FromAddress"] ?? username;
            var enableSsl = bool.Parse(smtpSettings["EnableSsl"] ?? "true");

            _logger.LogInformation("Đang gửi email tới {Email} qua SMTP {Host}:{Port}", email, host, port);

            try
            {
                using var client = new SmtpClient(host, port);
                client.UseDefaultCredentials = false;
                client.Credentials = new NetworkCredential(username, password);
                client.EnableSsl = enableSsl;

                var mailMessage = new MailMessage
                {
                    From = new MailAddress(from, "RestNDine"),
                    Subject = subject,
                    Body = htmlMessage,
                    IsBodyHtml = true,
                };
                mailMessage.To.Add(email);

                await client.SendMailAsync(mailMessage).WaitAsync(TimeSpan.FromSeconds(15));
                _logger.LogInformation("Gửi email thành công tới {Email}", email);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "SMTP thất bại khi gửi tới {Email}: {Message}", email, ex.Message);
                await WriteEmailToLocalHtmlAsync(email, subject, htmlMessage);
            }
        }

        private async Task WriteEmailToLocalHtmlAsync(string email, string subject, string htmlMessage)
        {
            try
            {
                var emailDir = Path.Combine(_env.WebRootPath, "sent_emails");
                Directory.CreateDirectory(emailDir);

                var fileName = $"email-{Guid.NewGuid()}.html";
                var filePath = Path.Combine(emailDir, fileName);

                var content = $@"<!DOCTYPE html>
<html lang=""vi"">
<head><meta charset=""utf-8""/><title>{subject}</title></head>
<body>
<p><strong>To:</strong> {email}</p>
<p><strong>Subject:</strong> {subject}</p>
<p><strong>Sent At:</strong> {DateTime.Now:dd/MM/yyyy HH:mm:ss}</p>
<hr/>
{htmlMessage}
</body>
</html>";

                await File.WriteAllTextAsync(filePath, content);
                _logger.LogWarning("[EMAIL FALLBACK] Lưu email tới {Email} tại /sent_emails/{FileName}", email, fileName);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Không thể lưu email fallback: {Message}", ex.Message);
            }
        }
    }
}
