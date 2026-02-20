using Microsoft.Extensions.Logging;
using Consul;
using AgileConfig.Server.SyncPlugin;
using AgileConfig.Server.SyncPlugin.Models;

namespace AgileConfig.Server.SyncPlugin.Plugins.Consul;

/// <summary>
/// Consul sync plugin implementation
/// </summary>
public class ConsulSyncPlugin : ISyncPlugin
{
    private readonly ILogger<ConsulSyncPlugin> _logger;
    private SyncPluginConfig? _config;
    private ConsulClient? _client;
    private string _keyPrefix = "agileconfig";

    public string Name => "consul";
    public string DisplayName => "Consul";
    public string Description => "Sync configs to HashiCorp Consul";

    public ConsulSyncPlugin(ILogger<ConsulSyncPlugin> logger)
    {
        _logger = logger;
    }

    public Task<SyncPluginResult> InitializeAsync(SyncPluginConfig config)
    {
        try
        {
            _config = config;

            // Get settings
            var address = config.Settings.GetValueOrDefault("address", "http://localhost:8500");
            _keyPrefix = config.Settings.GetValueOrDefault("keyPrefix", "agileconfig");

            _logger.LogInformation("Initializing Consul plugin with address: {Address}", address);

            var consulConfig = new ConsulClientConfiguration
            {
                Address = new Uri(address)
            };
            _client = new ConsulClient(consulConfig);

            return Task.FromResult(new SyncPluginResult { Success = true, Message = "Initialized" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to initialize Consul plugin");
            return Task.FromResult(new SyncPluginResult { Success = false, Message = ex.Message, Exception = ex });
        }
    }

    public async Task<SyncPluginResult> SyncAsync(SyncContext context)
    {
        try
        {
            var key = BuildKey(context);
            var value = context.Value;

            var kvp = new KVPair(key)
            {
                Value = System.Text.Encoding.UTF8.GetBytes(value)
            };

            await _client.KV.Put(kvp);
            _logger.LogInformation("Synced config {Key} to Consul", key);

            return new SyncPluginResult { Success = true, Message = $"Synced to {key}" };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to sync config to Consul");
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
                var kvp = new KVPair(key)
                {
                    Value = System.Text.Encoding.UTF8.GetBytes(context.Value)
                };
                await _client.KV.Put(kvp);
            }
            
            _logger.LogInformation("Batch synced {Count} configs to Consul", contexts.Count());

            return new SyncPluginResult { Success = true, Message = "Batch sync completed" };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to batch sync configs to Consul");
            return new SyncPluginResult { Success = false, Message = ex.Message, Exception = ex };
        }
    }

    public async Task<SyncPluginResult> DeleteAsync(SyncContext context)
    {
        try
        {
            var key = BuildKey(context);
            await _client.KV.Delete(key);
            _logger.LogInformation("Deleted config {Key} from Consul", key);

            return new SyncPluginResult { Success = true, Message = $"Deleted {key}" };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to delete config from Consul");
            return new SyncPluginResult { Success = false, Message = ex.Message, Exception = ex };
        }
    }

    public async Task<SyncPluginHealthResult> HealthCheckAsync()
    {
        try
        {
            var leader = await _client.Status.Leader();
            return new SyncPluginHealthResult
            {
                Healthy = true,
                Message = $"Consul leader: {leader}"
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Consul health check failed");
            return new SyncPluginHealthResult
            {
                Healthy = false,
                Message = ex.Message
            };
        }
    }

    public Task ShutdownAsync()
    {
        _logger.LogInformation("Consul plugin shutdown");
        _client?.Dispose();
        return Task.CompletedTask;
    }

    private string BuildKey(SyncContext context)
    {
        // Format: agileconfig/{appId}/{env}/{group}/{key}
        var group = string.IsNullOrEmpty(context.Group) ? "default" : context.Group;
        return $"{_keyPrefix}/{context.AppId}/{context.Env}/{group}/{context.Key}";
    }
}
