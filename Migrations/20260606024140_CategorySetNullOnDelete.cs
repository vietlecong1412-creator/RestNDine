using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DACS.Migrations
{
    /// <inheritdoc />
    public partial class CategorySetNullOnDelete : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Places_PlaceCategories_CategoryId",
                table: "Places");

            migrationBuilder.AlterColumn<int>(
                name: "CategoryId",
                table: "Places",
                type: "integer",
                nullable: true,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AddForeignKey(
                name: "FK_Places_PlaceCategories_CategoryId",
                table: "Places",
                column: "CategoryId",
                principalTable: "PlaceCategories",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Places_PlaceCategories_CategoryId",
                table: "Places");

            migrationBuilder.AlterColumn<int>(
                name: "CategoryId",
                table: "Places",
                type: "integer",
                nullable: false,
                defaultValue: 0,
                oldClrType: typeof(int),
                oldType: "integer",
                oldNullable: true);

            migrationBuilder.AddForeignKey(
                name: "FK_Places_PlaceCategories_CategoryId",
                table: "Places",
                column: "CategoryId",
                principalTable: "PlaceCategories",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
