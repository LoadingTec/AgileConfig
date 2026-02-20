using AgileConfig.Server.SyncPlugin.Models;

namespace AgileConfig.Server.SyncPlugin;

/// <summary>
/// Interface for sync plugins
/// All sync operations use "replace all" strategy: delete all + insert all
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
    /// Full sync: delete all + insert all for the given app+env
    /// This is the ONLY sync method - no need to handle add/update/delete separately
    /// </summary>
    /// <param name="contexts">All current published configs for the app+env</param>
    Task<SyncPluginResult> SyncAllAsync(SyncContext[] contexts);

    /// <summary>
    /// Health check for the plugin
    /// </summary>
    Task<SyncPluginHealthResult> HealthCheckAsync();

    /// <summary>
    /// Shutdown the plugin
    /// </summary>
    Task ShutdownAsync();
}
