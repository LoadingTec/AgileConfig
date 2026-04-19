using System.Reflection;
using AgileConfig.Server.Data.Entity;
using AgileConfig.Server.Data.Freesql;
using AgileConfig.Server.Data.Mongodb;
using FreeSql;
using MongoDB.Driver;

namespace AgileConfig.Tools.MigrateSqliteToMongo;

/// <summary>
///     Reads AgileConfig data from SQLite (FreeSql) and writes to MongoDB using the same entity types as the server.
/// </summary>
internal static class Program
{
    private static readonly Type[] MigrationOrder =
    [
        typeof(Role),
        typeof(Function),
        typeof(User),
        typeof(App),
        typeof(Setting),
        typeof(ServerNode),
        typeof(AppInheritanced),
        typeof(UserRole),
        typeof(UserAppAuth),
        typeof(RoleFunction),
        typeof(Config),
        typeof(ConfigPublished),
        typeof(PublishTimeline),
        typeof(PublishDetail),
        typeof(ServiceInfo),
        typeof(SysLog)
    ];

    private static int Main(string[] args)
    {
        try
        {
            return MainAsync(args).GetAwaiter().GetResult();
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"错误: {ex.Message}");
            Console.Error.WriteLine(ex);
            return 1;
        }
    }

    private static async Task<int> MainAsync(string[] args)
    {
        var sqliteConn = GetArgValue(args, "--sqlite");
        var mongoConn = GetArgValue(args, "--mongo");
        if (string.IsNullOrWhiteSpace(sqliteConn) || string.IsNullOrWhiteSpace(mongoConn))
        {
            PrintUsage();
            return 1;
        }

        var drop = HasFlag(args, "--drop");
        var dryRun = HasFlag(args, "--dry-run");
        var yes = HasFlag(args, "--yes") || HasFlag(args, "-y");

        if (drop && !dryRun && !yes)
        {
            Console.WriteLine("使用 --drop 将在写入每个集合前删除 MongoDB 中同名集合。");
            Console.WriteLine("若确认，请追加 --yes 或 -y。");
            return 1;
        }

        var sqliteCs = sqliteConn.Trim();
        if (!sqliteCs.Contains("Busy", StringComparison.OrdinalIgnoreCase))
            sqliteCs = sqliteCs.TrimEnd(';') + ";Busy Timeout=15000";

        using var sqlite = new FreeSqlBuilder()
            .UseConnectionString(DataType.Sqlite, sqliteCs)
            .Build();
        FluentApi.Config(sqlite);

        if (!EnsureTables.ExistTable(sqlite))
        {
            Console.Error.WriteLine("SQLite 中未检测到 AgileConfig 表（agc_app）。请确认连接串指向正确的 agile_config.db。");
            return 1;
        }

        Console.WriteLine("SQLite 源已连接。");
        Console.WriteLine(dryRun ? "模式: 仅统计（dry-run）" : drop ? "模式: 每集合写入前 Drop 再插入" : "模式: 仅插入（_id 冲突将失败，建议 --drop --yes）");

        foreach (var type in MigrationOrder)
        {
            var migrate = typeof(Program).GetMethod(nameof(MigrateOneAsync), BindingFlags.NonPublic | BindingFlags.Static);
            var generic = migrate!.MakeGenericMethod(type);
            await (Task)generic.Invoke(null, [sqlite, mongoConn, drop, dryRun])!;
        }

        Console.WriteLine(dryRun ? "Dry-run 完成。" : "迁移完成。");
        return 0;
    }

    private static async Task MigrateOneAsync<T>(IFreeSql sqlite, string mongoConn, bool drop, bool dryRun) where T : class, new()
    {
        var count = await sqlite.Select<T>().CountAsync();
        Console.WriteLine($"  {typeof(T).Name,-22}: {count} 行");

        if (dryRun || count == 0)
            return;

        var access = new MongodbAccess<T>(mongoConn);
        if (drop)
            await TryDropCollectionAsync(access.Database, access.CollectionName);

        var rows = await sqlite.Select<T>().ToListAsync();
        if (rows.Count > 0)
            await access.Collection.InsertManyAsync(rows);
    }

    private static async Task TryDropCollectionAsync(IMongoDatabase db, string name)
    {
        try
        {
            await db.DropCollectionAsync(name);
        }
        catch (MongoCommandException ex) when (ex.CodeName == "NamespaceNotFound" || ex.Code == 26)
        {
            // 集合不存在时忽略
        }
    }

    private static string? GetArgValue(string[] args, string name)
    {
        for (var i = 0; i < args.Length - 1; i++)
            if (string.Equals(args[i], name, StringComparison.OrdinalIgnoreCase))
                return args[i + 1];

        return null;
    }

    private static bool HasFlag(string[] args, string flag)
    {
        return args.Any(a => string.Equals(a, flag, StringComparison.OrdinalIgnoreCase));
    }

    private static void PrintUsage()
    {
        Console.WriteLine(
            """
            AgileConfig: SQLite -> MongoDB 迁移工具

            用法:
              dotnet run --project <本.csproj路径> -- --sqlite "<SQLite连接串>" --mongo "<MongoDB URI>" [选项]

            必选:
              --sqlite   SQLite 连接串，例如: Data Source=C:\app\agile_config.db
              --mongo    MongoDB 连接串，例如: mongodb://user:pass@host:27017/AgileConfig

            选项:
              --drop     写入前删除目标同名集合（需配合 --yes）
              --dry-run  只统计各表行数，不写入 MongoDB
              --yes / -y 与 --drop 同时使用时跳过确认提示

            说明:
              - 默认仅插入；若 Mongo 已有数据且 _id 重复会失败，完整覆盖请使用 --drop --yes。
              - 迁移后请将服务端 db:provider= mongodb、db:conn= 指向目标 URI，并重启服务。
            """);
    }
}
