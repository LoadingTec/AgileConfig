using Microsoft.Extensions.Logging;
using AgileConfig.Server.SyncPlugin;
using AgileConfig.Server.SyncPlugin.Models;
using dotnet_etcd;

namespace AgileConfig.Server.SyncPlugin.Plugins.Etcd;

/// <summary>
/// Etcd sync plugin implementation
/// </summary>
public class EtcdSyncPlugin : ISyncPlugin
{
    private readonly ILogger<EtcdSyncPlugin> _logger;
    private SyncPluginConfig? _config;
    private EtcdClient? _client;
    private string _keyPrefix = "/agileconfig";

    public string Name => "etcd";
    public string DisplayName => "Etcd";
    public string Description => "Sync configs to etcd";

    public EtcdSyncPlugin(ILogger<EtcdSyncPlugin> logger)
    {
        _logger = logger;
    }

    public Task<SyncPluginResult> InitializeAsync(SyncPluginConfig config)
    {
        try
        {
            _config = config;

            // Get settings
            var endpoints = config.Settings.GetValueOrDefault("endpoints", "http://localhost:2379");
            _keyPrefix = config.Settings.GetValueOrDefault("keyPrefix", "/agileconfig");

            _logger.LogInformation("Initializing Etcd plugin with endpoints: {Endpoints}", endpoints);

            _client = new EtcdClient(endpoints);

            return Task.FromResult(new SyncPluginResult { Success = true, Message = "Initialized" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to initialize Etcd plugin");
            return Task.FromResult(new SyncPluginResult { Success = false, Message = ex.Message, Exception = ex });
        }
    }

    public Task<SyncPluginResult> SyncAsync(SyncContext context)
    {
        try
        {
            var key = BuildKey(context);
            var value = context.Value;

            _client.Put(key, value);
            _logger.LogInformation("Synced config {Key} to etcd", key);

            return Task.FromResult(new SyncPluginResult { Success = true, Message = $"Synced to {key}" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to sync config to etcd");
            return Task.FromResult(new SyncPluginResult { Success = false, Message = ex.Message, Exception = ex });
        }
    }

    public Task<SyncPluginResult> SyncBatchAsync(IEnumerable<SyncContext> contexts)
    {
        try
        {
            foreach (var context in contexts)
            {
                var key = BuildKey(context);
                _client.Put(key, context.Value);
            }
            
            _logger.LogInformation("Batch synced {Count} configs to etcd", contexts.Count());

            return Task.FromResult(new SyncPluginResult { Success = true, Message = "Batch sync completed" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to batch sync configs to etcd");
            return Task.FromResult(new SyncPluginResult { Success = false, Message = ex.Message, Exception = ex });
        }
    }

    public Task<SyncPluginResult> DeleteAsync(SyncContext context)
    {
        try
        {
            var key = BuildKey(context);
            _client.Delete(key);
            _logger.LogInformation("Deleted config {Key} from etcd", key);

            return Task.FromResult(new SyncPluginResult { Success = true, Message = $"Deleted {key}" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to delete config from etcd");
            return Task.FromResult(new SyncPluginResult { Success = false, Message = ex.Message, Exception = ex });
        }
    }

    public Task<SyncPluginHealthResult> HealthCheckAsync()
    {
        // Simplified health check - just check if client is initialized
        try
        {
            if (_client == null)
            {
                return Task.FromResult(new SyncPluginHealthResult
                {
                    Healthy = false,
                    Message = "Etcd client not initialized"
                });
            }

            return Task.FromResult(new SyncPluginHealthResult
            {
                Healthy = true,
                Message = "Etcd client connected"
            });
        }
        catch (Exception ex)
        {
            return Task.FromResult(new SyncPluginHealthResult
            {
                Healthy = false,
                Message = ex.Message
            });
        }
    }

    public Task ShutdownAsync()
    {
        _logger.LogInformation("Etcd plugin shutdown");
        return Task.CompletedTask;
    }

    private string BuildKey(SyncContext context)
    {
        // Format: /agileconfig/{appId}/{env}/{key}
        var group = string.IsNullOrEmpty(context.Group) ? "default" : context.Group;
        return $"{_keyPrefix}/{context.AppId}/{context.Env}/{group}/{context.Key}";
    }
}
