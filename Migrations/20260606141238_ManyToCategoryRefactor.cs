using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DACS.Migrations
{
    /// <inheritdoc />
    public partial class ManyToCategoryRefactor : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Places_PlaceCategories_CategoryId",
                table: "Places");

            migrationBuilder.DropIndex(
                name: "IX_Places_CategoryId",
                table: "Places");

            migrationBuilder.DropColumn(
                name: "CategoryId",
                table: "Places");

            migrationBuilder.CreateTable(
                name: "PlaceCategoryAssignments",
                columns: table => new
                {
                    CategoriesId = table.Column<int>(type: "integer", nullable: false),
                    PlacesId = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PlaceCategoryAssignments", x => new { x.CategoriesId, x.PlacesId });
                    table.ForeignKey(
                        name: "FK_PlaceCategoryAssignments_PlaceCategories_CategoriesId",
                        column: x => x.CategoriesId,
                        principalTable: "PlaceCategories",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_PlaceCategoryAssignments_Places_PlacesId",
                        column: x => x.PlacesId,
                        principalTable: "Places",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_PlaceCategoryAssignments_PlacesId",
                table: "PlaceCategoryAssignments",
                column: "PlacesId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "PlaceCategoryAssignments");

            migrationBuilder.AddColumn<int>(
                name: "CategoryId",
                table: "Places",
                type: "integer",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Places_CategoryId",
                table: "Places",
                column: "CategoryId");

            migrationBuilder.AddForeignKey(
                name: "FK_Places_PlaceCategories_CategoryId",
                table: "Places",
                column: "CategoryId",
                principalTable: "PlaceCategories",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }
    }
}
