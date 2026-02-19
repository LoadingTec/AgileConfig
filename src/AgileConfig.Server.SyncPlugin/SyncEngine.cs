using Microsoft.Extensions.Logging;
using AgileConfig.Server.SyncPlugin.Models;

namespace AgileConfig.Server.SyncPlugin;

/// <summary>
/// Sync engine that manages all plugins and handles config synchronization
/// </summary>
public class SyncEngine : IDisposable
{
    private readonly ILogger<SyncEngine> _logger;
    private readonly Dictionary<string, ISyncPlugin> _plugins = new();
    private readonly Dictionary<string, SyncPluginConfig> _pluginConfigs = new();
    private bool _initialized = false;
    private readonly object _lock = new();

    public SyncEngine(ILogger<SyncEngine> logger)
    {
        _logger = logger;
    }

    /// <summary>
    /// Register a sync plugin
    /// </summary>
    public void RegisterPlugin(ISyncPlugin plugin, SyncPluginConfig config)
    {
        lock (_lock)
        {
            if (_plugins.ContainsKey(plugin.Name))
            {
                _logger.LogWarning("Plugin {PluginName} already registered, skipping", plugin.Name);
                return;
            }

            _plugins[plugin.Name] = plugin;
            _pluginConfigs[plugin.Name] = config;
            _logger.LogInformation("Registered sync plugin: {PluginName}", plugin.Name);
        }
    }

    /// <summary>
    /// Initialize all registered plugins
    /// </summary>
    public async Task InitializeAsync()
    {
        if (_initialized) return;

        lock (_lock)
        {
            if (_initialized) return;
            _initialized = true;
        }

        foreach (var kvp in _plugins)
        {
            var pluginName = kvp.Key;
            var plugin = kvp.Value;
            var config = _pluginConfigs[pluginName];

            try
            {
                var result = await plugin.InitializeAsync(config);
                if (result.Success)
                {
                    _logger.LogInformation("Initialized sync plugin: {PluginName}", pluginName);
                }
                else
                {
                    _logger.LogError("Failed to initialize plugin {PluginName}: {Message}", pluginName, result.Message);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Exception initializing plugin {PluginName}", pluginName);
            }
        }
    }

    /// <summary>
    /// Sync a config change to all enabled plugins
    /// </summary>
    public async Task<SyncPluginResult> SyncAsync(SyncContext context)
    {
        var tasks = _plugins.Values
            .Where(p => IsPluginEnabled(p.Name))
            .Select(p => SafeExecuteAsync(p.SyncAsync(context)));

        var results = await Task.WhenAll(tasks);
        
        var failed = results.Where(r => !r.Success).ToList();
        if (failed.Any())
        {
            return new SyncPluginResult
            {
                Success = false,
                Message = $"Sync failed for {failed.Count} plugins: {string.Join(", ", failed.Select(f => f.Message))}"
            };
        }

        return new SyncPluginResult { Success = true, Message = "Synced to all enabled plugins" };
    }

    /// <summary>
    /// Sync multiple config changes in batch
    /// </summary>
    public async Task<SyncPluginResult> SyncBatchAsync(IEnumerable<SyncContext> contexts)
    {
        var contextList = contexts.ToList();
        if (!contextList.Any())
        {
            return new SyncPluginResult { Success = true, Message = "No contexts to sync" };
        }

        var tasks = _plugins.Values
            .Where(p => IsPluginEnabled(p.Name))
            .Select(p => SafeExecuteAsync(p.SyncBatchAsync(contextList)));

        var results = await Task.WhenAll(tasks);

        var failed = results.Where(r => !r.Success).ToList();
        if (failed.Any())
        {
            return new SyncPluginResult
            {
                Success = false,
                Message = $"Batch sync failed for {failed.Count} plugins: {string.Join(", ", failed.Select(f => f.Message))}"
            };
        }

        return new SyncPluginResult { Success = true, Message = "Batch synced to all enabled plugins" };
    }

    /// <summary>
    /// Delete a config from all enabled plugins
    /// </summary>
    public async Task<SyncPluginResult> DeleteAsync(SyncContext context)
    {
        var tasks = _plugins.Values
            .Where(p => IsPluginEnabled(p.Name))
            .Select(p => SafeExecuteAsync(p.DeleteAsync(context)));

        var results = await Task.WhenAll(tasks);

        var failed = results.Where(r => !r.Success).ToList();
        if (failed.Any())
        {
            return new SyncPluginResult
            {
                Success = false,
                Message = $"Delete failed for {failed.Count} plugins: {string.Join(", ", failed.Select(f => f.Message))}"
            };
        }

        return new SyncPluginResult { Success = true, Message = "Deleted from all enabled plugins" };
    }

    /// <summary>
    /// Check health of all plugins
    /// </summary>
    public async Task<Dictionary<string, SyncPluginHealthResult>> HealthCheckAsync()
    {
        var tasks = _plugins.Values
            .Where(p => IsPluginEnabled(p.Name))
            .Select(async p =>
            {
                try
                {
                    var result = await p.HealthCheckAsync();
                    return (Name: p.Name, Result: result);
                }
                catch (Exception ex)
                {
                    return (Name: p.Name, Result: new SyncPluginHealthResult
                    {
                        Healthy = false,
                        Message = ex.Message
                    });
                }
            });

        var results = await Task.WhenAll(tasks);
        return results.ToDictionary(r => r.Name, r => r.Result);
    }

    /// <summary>
    /// Get all registered plugins
    /// </summary>
    public IReadOnlyDictionary<string, ISyncPlugin> GetPlugins() => _plugins;

    /// <summary>
    /// Get plugin by name
    /// </summary>
    public ISyncPlugin? GetPlugin(string name) => _plugins.GetValueOrDefault(name);

    private bool IsPluginEnabled(string pluginName)
    {
        if (!_pluginConfigs.TryGetValue(pluginName, out var config))
            return false;

        return config.Enabled?.ToLower() == "true";
    }

    private async Task<SyncPluginResult> SafeExecuteAsync(Func<Task<SyncPluginResult>> action)
    {
        try
        {
            return await action();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Exception during sync operation");
            return new SyncPluginResult
            {
                Success = false,
                Message = ex.Message,
                Exception = ex
            };
        }
    }

    public async Task ShutdownAsync()
    {
        foreach (var plugin in _plugins.Values)
        {
            try
            {
                await plugin.ShutdownAsync();
                _logger.LogInformation("Shutdown plugin: {PluginName}", plugin.Name);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error shutting down plugin: {PluginName}", plugin.Name);
            }
        }
    }

    public void Dispose()
    {
        ShutdownAsync().GetAwaiter().GetResult();
    }
}
