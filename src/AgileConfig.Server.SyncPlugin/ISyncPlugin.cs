using AgileConfig.Server.SyncPlugin.Models;

namespace AgileConfig.Server.SyncPlugin;

/// <summary>
/// Interface for sync plugins
/// </summary>
public interface ISyncPlugin
{
    /// <summary>
    /// Unique name of the plugin
    /// </summary>
    string Name { get; }

    /// <summary>
    /// Display name for UI
    /// </summary>
    string DisplayName { get; }

    /// <summary>
    /// Description of the plugin
    /// </summary>
    string Description { get; }

    /// <summary>
    /// Initialize the plugin with configuration
    /// </summary>
    Task<SyncPluginResult> InitializeAsync(SyncPluginConfig config);

    /// <summary>
    /// Sync a single config change
    /// </summary>
    Task<SyncPluginResult> SyncAsync(SyncContext context);

    /// <summary>
    /// Sync multiple config changes in batch
    /// </summary>
    Task<SyncPluginResult> SyncBatchAsync(IEnumerable<SyncContext> contexts);

    /// <summary>
    /// Delete a config from the external system
    /// </summary>
    Task<SyncPluginResult> DeleteAsync(SyncContext context);

    /// <summary>
    /// Health check for the plugin
    /// </summary>
    Task<SyncPluginHealthResult> HealthCheckAsync();

    /// <summary>
    /// Shutdown the plugin
    /// </summary>
    Task ShutdownAsync();
}
