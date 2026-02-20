using Microsoft.Extensions.Logging;
using AgileConfig.Server.SyncPlugin;
using AgileConfig.Server.SyncPlugin.Models;
using Etcd.Client;

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

            var endpointsArray = endpoints.Split(',').Select(e => e.Trim()).ToArray();
            _client = new EtcdClient(endpointsArray);

            return Task.FromResult(new SyncPluginResult { Success = true, Message = "Initialized" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to initialize Etcd plugin");
            return Task.FromResult(new SyncPluginResult { Success = false, Message = ex.Message, Exception = ex });
        }
    }

    public async Task<SyncPluginResult> SyncAsync(SyncContext context)
    {
        try
        {
            var key = BuildKey(context);
            var value = context.Value;

            await _client.PutAsync(key, value);
            _logger.LogInformation("Synced config {Key} to etcd", key);

            return new SyncPluginResult { Success = true, Message = $"Synced to {key}" };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to sync config to etcd");
            return new SyncPluginResult { Success = false, Message = ex.Message, Exception = ex };
        }
    }

    public async Task<SyncPluginResult> SyncBatchAsync(IEnumerable<SyncContext> contexts)
    {
        try
        {
            foreach (var context in contexts)
            {
                var key = BuildKey(context);
                await _client.PutAsync(key, context.Value);
            }
            
            _logger.LogInformation("Batch synced {Count} configs to etcd", contexts.Count());

            return new SyncPluginResult { Success = true, Message = "Batch sync completed" };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to batch sync configs to etcd");
            return new SyncPluginResult { Success = false, Message = ex.Message, Exception = ex };
        }
    }

    public async Task<SyncPluginResult> DeleteAsync(SyncContext context)
    {
        try
        {
            var key = BuildKey(context);
            await _client.DeleteAsync(key);
            _logger.LogInformation("Deleted config {Key} from etcd", key);

            return new SyncPluginResult { Success = true, Message = $"Deleted {key}" };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to delete config from etcd");
            return new SyncPluginResult { Success = false, Message = ex.Message, Exception = ex };
        }
    }

    public async Task<SyncPluginHealthResult> HealthCheckAsync()
    {
        try
        {
            var version = await _client.GetVersionAsync();
            return new SyncPluginHealthResult
            {
                Healthy = true,
                Message = $"Etcd version: {version}"
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Etcd health check failed");
            return new SyncPluginHealthResult
            {
                Healthy = false,
                Message = ex.Message
            };
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
