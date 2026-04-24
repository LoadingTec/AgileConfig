using Microsoft.AspNetCore.Http.Features;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod();
    });
});

builder.Services.Configure<FormOptions>(o =>
{
    o.MultipartBodyLengthLimit = 20 * 1024 * 1024;
});

var app = builder.Build();
app.UseCors();

var uploadDir = Path.Combine(app.Environment.ContentRootPath, "uploads");
Directory.CreateDirectory(uploadDir);

app.MapGet("/api/health", () =>
    Results.Ok(new { ok = true, utc = DateTime.UtcNow, machine = Environment.MachineName }));

app.MapPost("/api/submit", async (HttpRequest request) =>
{
    if (!request.HasFormContentType)
        return Results.BadRequest(new { error = "Content-Type 须为 multipart/form-data" });

    var form = await request.ReadFormAsync();
    var name = form["name"].ToString();
    var remark = form["remark"].ToString();
    if (string.IsNullOrWhiteSpace(name))
        return Results.BadRequest(new { error = "name 必填" });

    string? savedName = null;
    long? size = null;
    var file = form.Files.GetFile("file");
    if (file is { Length: > 0 })
    {
        var safe = Path.GetFileName(file.FileName);
        if (string.IsNullOrEmpty(safe))
            safe = "upload.bin";
        savedName = $"{DateTime.UtcNow:yyyyMMddHHmmssfff}_{safe}";
        var path = Path.Combine(uploadDir, savedName);
        await using (var fs = File.Create(path))
        {
            await file.CopyToAsync(fs);
        }
        size = new FileInfo(path).Length;
    }

    return Results.Ok(new
    {
        message = "已处理",
        name,
        remark,
        file = savedName,
        bytes = size,
    });
}).DisableAntiforgery();

app.Run();
