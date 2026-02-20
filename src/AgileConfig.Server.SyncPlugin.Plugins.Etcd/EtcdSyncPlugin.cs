using Microsoft.Extensions.Logging;
using AgileConfig.Server.SyncPlugin;
using AgileConfig.Server.SyncPlugin.Models;
using dotnet_etcd;

namespace AgileConfig.Server.SyncPlugin.Plugins.Etcd;

/// <summary>
/// Etcd sync plugin implementation
/// Uses "replace all" strategy: delete all keys for app+env, then insert all
/// </summary>
public class EtcdSyncPlugin : ISyncPlugin
{
    private readonly ILogger<EtcdSyncPlugin> _logger;
    private SyncPluginConfig? _config;
    private EtcdClient? _client;
    private string _keyPrefix = "/agileconfig";

    public string Name => "etcd";
    public string DisplayName => "Etcd";
    public string Description => "Sync configs to etcd using replace-all strategy";

    public EtcdSyncPlugin(ILogger<EtcdSyncPlugin> logger)
    {
        _logger = logger;
    }

    public Task<SyncPluginResult> InitializeAsync(SyncPluginConfig config)
    {
        try
        {
            _config = config;

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

    /// <summary>
    /// Full sync: delete all + insert all
    /// </summary>
    public Task<SyncPluginResult> SyncAllAsync(SyncContext[] contexts)
    {
        if (contexts == null || contexts.Length == 0)
        {
            _logger.LogInformation("No configs to sync");
            return Task.FromResult(new SyncPluginResult { Success = true, Message = "No configs to sync" });
        }

        try
        {
            var appId = contexts[0].AppId;
            var env = contexts[0].Env;
            var prefix = $"{_keyPrefix}/{appId}/{env}/";

            // Delete all existing keys with prefix
            _client.Delete(prefix);

            // Insert all new configs
            foreach (var context in contexts)
            {
                var key = BuildKey(context);
                _client.Put(key, context.Value);
            }

            _logger.LogInformation("Synced {Count} configs to etcd for app {AppId} env {Env}", 
                contexts.Length, appId, env);

            return Task.FromResult(new SyncPluginResult 
            { 
                Success = true, 
                Message = $"Synced {contexts.Length} configs" 
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to sync configs to etcd");
            return Task.FromResult(new SyncPluginResult { Success = false, Message = ex.Message, Exception = ex });
        }
    }

    public Task<SyncPluginHealthResult> HealthCheckAsync()
    {
        return Task.FromResult(new SyncPluginHealthResult
        {
            Healthy = true,
            Message = "Etcd plugin initialized"
        });
    }

    public Task ShutdownAsync()
    {
        _logger.LogInformation("Etcd plugin shutdown");
        return Task.CompletedTask;
    }

    private string BuildKey(SyncContext context)
    {
        var group = string.IsNullOrEmpty(context.Group) ? "default" : context.Group;
        return $"{_keyPrefix}/{context.AppId}/{context.Env}/{group}/{context.Key}";
    }
}
