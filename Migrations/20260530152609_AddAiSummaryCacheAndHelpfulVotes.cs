using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DACS.Migrations
{
    /// <inheritdoc />
    public partial class AddAiSummaryCacheAndHelpfulVotes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "AiSummaryCache",
                table: "Places",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "AiSummaryCacheUpdatedAt",
                table: "Places",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "HelpfulCount",
                table: "PlaceComments",
                type: "integer",
                nullable: false,
                defaultValue: 0);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "AiSummaryCache",
                table: "Places");

            migrationBuilder.DropColumn(
                name: "AiSummaryCacheUpdatedAt",
                table: "Places");

            migrationBuilder.DropColumn(
                name: "HelpfulCount",
                table: "PlaceComments");
        }
    }
}
