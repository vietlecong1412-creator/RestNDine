using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace DACS.Migrations
{
    /// <inheritdoc />
    public partial class AddPlaceTablesAndCopyData : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "PlaceCategories",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    Name = table.Column<string>(type: "text", nullable: false),
                    Slug = table.Column<string>(type: "text", nullable: false),
                    Icon = table.Column<string>(type: "text", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PlaceCategories", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Places",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    Name = table.Column<string>(type: "text", nullable: false),
                    Address = table.Column<string>(type: "text", nullable: true),
                    Latitude = table.Column<double>(type: "double precision", nullable: false),
                    Longitude = table.Column<double>(type: "double precision", nullable: false),
                    Description = table.Column<string>(type: "text", nullable: true),
                    ImageUrl = table.Column<string>(type: "text", nullable: true),
                    PhoneNumber = table.Column<string>(type: "text", nullable: true),
                    PriceRange = table.Column<string>(type: "text", nullable: true),
                    BannerUrl = table.Column<string>(type: "text", nullable: true),
                    PaymentProofUrl = table.Column<string>(type: "text", nullable: true),
                    BannerStatus = table.Column<int>(type: "integer", nullable: false),
                    IsApproved = table.Column<bool>(type: "boolean", nullable: false),
                    CategoryId = table.Column<int>(type: "integer", nullable: false),
                    StarRating = table.Column<int>(type: "integer", nullable: true),
                    Amenities = table.Column<string>(type: "text", nullable: true),
                    OwnerId = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Places", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Places_AspNetUsers_OwnerId",
                        column: x => x.OwnerId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_Places_PlaceCategories_CategoryId",
                        column: x => x.CategoryId,
                        principalTable: "PlaceCategories",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "PlaceComments",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    Content = table.Column<string>(type: "text", nullable: false),
                    Rating = table.Column<int>(type: "integer", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    PlaceId = table.Column<int>(type: "integer", nullable: false),
                    UserId = table.Column<string>(type: "text", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PlaceComments", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PlaceComments_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_PlaceComments_Places_PlaceId",
                        column: x => x.PlaceId,
                        principalTable: "Places",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "PlaceImages",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    ImageUrl = table.Column<string>(type: "text", nullable: false),
                    PlaceId = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PlaceImages", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PlaceImages_Places_PlaceId",
                        column: x => x.PlaceId,
                        principalTable: "Places",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_PlaceComments_PlaceId",
                table: "PlaceComments",
                column: "PlaceId");

            migrationBuilder.CreateIndex(
                name: "IX_PlaceComments_UserId",
                table: "PlaceComments",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_PlaceImages_PlaceId",
                table: "PlaceImages",
                column: "PlaceId");

            migrationBuilder.CreateIndex(
                name: "IX_Places_CategoryId",
                table: "Places",
                column: "CategoryId");

            migrationBuilder.CreateIndex(
                name: "IX_Places_OwnerId",
                table: "Places",
                column: "OwnerId");

            // ── SEED PlaceCategories ──────────────────────────────────
            migrationBuilder.Sql(@"
                INSERT INTO ""PlaceCategories"" (""Id"", ""Name"", ""Slug"", ""Icon"") VALUES
                (1, N'Nhà hàng',    'restaurant', '🍴'),
                (2, N'Khách sạn',   'hotel',      '🏨'),
                (3, N'Quán cà phê', 'cafe',       '☕')
                ON CONFLICT (""Id"") DO NOTHING;
            ");

            // ── COPY Restaurants → Places ─────────────────────────────
            // IsCafe = true  → CategoryId = 3 (Quán cà phê)
            // IsCafe = false → CategoryId = 1 (Nhà hàng)
            migrationBuilder.Sql(@"
                INSERT INTO ""Places"" (
                    ""Name"", ""Address"", ""Latitude"", ""Longitude"", ""Description"",
                    ""ImageUrl"", ""PhoneNumber"", ""PriceRange"",
                    ""BannerUrl"", ""PaymentProofUrl"", ""BannerStatus"",
                    ""IsApproved"", ""OwnerId"", ""CategoryId"",
                    ""StarRating"", ""Amenities""
                )
                SELECT
                    r.""Name"", r.""Address"", r.""Latitude"", r.""Longitude"", r.""Description"",
                    r.""ImageUrl"", r.""PhoneNumber"", r.""PriceRange"",
                    r.""BannerUrl"", r.""PaymentProofUrl"", r.""BannerStatus"",
                    r.""IsApproved"", r.""OwnerId"",
                    CASE WHEN r.""IsCafe"" = TRUE THEN 3 ELSE 1 END,
                    NULL, NULL
                FROM ""Restaurants"" r;
            ");

            // ── COPY RestaurantImages → PlaceImages ───────────────────
            // Mapping: Places.Id được gán theo thứ tự insert (cùng Id với Restaurants nếu bảng Places mới bắt đầu từ 1)
            // Dùng subquery để map đúng PlaceId dựa theo Name (an toàn hơn)
            migrationBuilder.Sql(@"
                INSERT INTO ""PlaceImages"" (""ImageUrl"", ""PlaceId"")
                SELECT ri.""ImageUrl"", p.""Id""
                FROM ""RestaurantImages"" ri
                JOIN ""Restaurants"" r ON r.""Id"" = ri.""RestaurantId""
                JOIN ""Places"" p ON p.""Name"" = r.""Name""
                    AND p.""Latitude"" = r.""Latitude""
                    AND p.""Longitude"" = r.""Longitude"";
            ");

            // ── COPY Comments → PlaceComments ─────────────────────────
            migrationBuilder.Sql(@"
                INSERT INTO ""PlaceComments"" (""Content"", ""Rating"", ""CreatedAt"", ""PlaceId"", ""UserId"")
                SELECT c.""Content"", c.""Rating"", c.""CreatedAt"", p.""Id"", c.""UserId""
                FROM ""Comments"" c
                JOIN ""Restaurants"" r ON r.""Id"" = c.""RestaurantId""
                JOIN ""Places"" p ON p.""Name"" = r.""Name""
                    AND p.""Latitude"" = r.""Latitude""
                    AND p.""Longitude"" = r.""Longitude"";
            ");

            // ── COPY Hotels → Places ──────────────────────────────────
            migrationBuilder.Sql(@"
                INSERT INTO ""Places"" (
                    ""Name"", ""Address"", ""Latitude"", ""Longitude"", ""Description"",
                    ""ImageUrl"", ""PhoneNumber"", ""PriceRange"",
                    ""BannerUrl"", ""PaymentProofUrl"", ""BannerStatus"",
                    ""IsApproved"", ""OwnerId"", ""CategoryId"",
                    ""StarRating"", ""Amenities""
                )
                SELECT
                    h.""Name"", h.""Address"", h.""Latitude"", h.""Longitude"", h.""Description"",
                    h.""ImageUrl"", h.""PhoneNumber"", h.""PriceRange"",
                    h.""BannerUrl"", h.""PaymentProofUrl"", h.""BannerStatus"",
                    h.""IsApproved"", h.""OwnerId"",
                    2,
                    h.""StarRating"", h.""Amenities""
                FROM ""Hotels"" h;
            ");

            // ── COPY HotelImages → PlaceImages ────────────────────────
            migrationBuilder.Sql(@"
                INSERT INTO ""PlaceImages"" (""ImageUrl"", ""PlaceId"")
                SELECT hi.""ImageUrl"", p.""Id""
                FROM ""HotelImages"" hi
                JOIN ""Hotels"" h ON h.""Id"" = hi.""HotelId""
                JOIN ""Places"" p ON p.""Name"" = h.""Name""
                    AND p.""Latitude"" = h.""Latitude""
                    AND p.""Longitude"" = h.""Longitude"";
            ");

            // ── COPY HotelComments → PlaceComments ────────────────────
            migrationBuilder.Sql(@"
                INSERT INTO ""PlaceComments"" (""Content"", ""Rating"", ""CreatedAt"", ""PlaceId"", ""UserId"")
                SELECT hc.""Content"", hc.""Rating"", hc.""CreatedAt"", p.""Id"", hc.""UserId""
                FROM ""HotelComments"" hc
                JOIN ""Hotels"" h ON h.""Id"" = hc.""HotelId""
                JOIN ""Places"" p ON p.""Name"" = h.""Name""
                    AND p.""Latitude"" = h.""Latitude""
                    AND p.""Longitude"" = h.""Longitude"";
            ");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "PlaceComments");

            migrationBuilder.DropTable(
                name: "PlaceImages");

            migrationBuilder.DropTable(
                name: "Places");

            migrationBuilder.DropTable(
                name: "PlaceCategories");
        }
    }
}
