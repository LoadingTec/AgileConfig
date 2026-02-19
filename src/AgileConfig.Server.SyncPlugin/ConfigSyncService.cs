using Microsoft.Extensions.Logging;
using AgileConfig.Server.Data.Entity;
using AgileConfig.Server.SyncPlugin.Models;

namespace AgileConfig.Server.SyncPlugin;

/// <summary>
/// Service that handles config sync operations
/// This service can be called when config changes in the system
/// </summary>
public class ConfigSyncService
{
    private readonly SyncEngine _syncEngine;
    private readonly ILogger<ConfigSyncService> _logger;

    public ConfigSyncService(SyncEngine syncEngine, ILogger<ConfigSyncService> logger)
    {
        _syncEngine = syncEngine;
        _logger = logger;
    }

    /// <summary>
    /// Sync a config when it's added or updated
    /// </summary>
    public async Task<bool> SyncConfigAsync(Config config, string env, SyncOperationType operationType)
    {
        var context = new SyncContext
        {
            AppId = config.AppId,
            AppName = config.AppName ?? "",
            Env = env,
            Key = config.Key,
            Value = config.Value ?? "",
            Group = config.GroupName,
            OperationType = operationType,
            Timestamp = DateTimeOffset.UtcNow
        };

        try
        {
            var result = operationType == SyncOperationType.Delete 
                ? await _syncEngine.DeleteAsync(context)
                : await _syncEngine.SyncAsync(context);

            if (result.Success)
            {
                _logger.LogInformation("Config {Key} synced successfully", config.Key);
            }
            else
            {
                _logger.LogWarning("Config {Key} sync failed: {Message}", config.Key, result.Message);
            }

            return result.Success;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Exception syncing config {Key}", config.Key);
            return false;
        }
    }

    /// <summary>
    /// Batch sync multiple configs
    /// </summary>
    public async Task<bool> BatchSyncConfigsAsync(IEnumerable<Config> configs, string env)
    {
        var contexts = configs.Select(c => new SyncContext
        {
            AppId = c.AppId,
            AppName = c.AppName ?? "",
            Env = env,
            Key = c.Key,
            Value = c.Value ?? "",
            Group = c.GroupName,
            OperationType = SyncOperationType.Add,
            Timestamp = DateTimeOffset.UtcNow
        }).ToList();

        try
        {
            var result = await _syncEngine.SyncBatchAsync(contexts);
            return result.Success;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Exception batch syncing configs");
            return false;
        }
    }

    /// <summary>
    /// Health check all sync plugins
    /// </summary>
    public async Task<Dictionary<string, SyncPluginHealthResult>> HealthCheckAsync()
    {
        return await _syncEngine.HealthCheckAsync();
    }
}
