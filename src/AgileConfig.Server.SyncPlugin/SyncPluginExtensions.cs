using AgileConfig.Server.SyncPlugin;
using AgileConfig.Server.SyncPlugin.Plugins.Consul;
using AgileConfig.Server.SyncPlugin.Plugins.Etcd;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace AgileConfig.Server.SyncPlugin;

/// <summary>
/// Extension methods for registering SyncPlugin services and plugins
/// </summary>
public static class SyncPluginExtensions
{
    /// <summary>
    /// Add SyncPlugin services to the service collection
    /// </summary>
    public static IServiceCollection AddSyncPlugin(this IServiceCollection services)
    {
        services.AddSingleton<SyncEngine>();

        return services;
    }

    /// <summary>
    /// Register built-in sync plugins (call after AddSyncPlugin)
    /// This is typically called during app startup
    /// </summary>
    public static void RegisterBuiltInPlugins(SyncEngine syncEngine, ILoggerFactory loggerFactory)
    {
        // Register Etcd plugin
        var etcdLogger = loggerFactory.CreateLogger<EtcdSyncPlugin>();
        var etcdPlugin = new EtcdSyncPlugin(etcdLogger);
        syncEngine.RegisterPlugin(etcdPlugin, new SyncPluginConfig
        {
            PluginName = "etcd",
            Enabled = "false", // Disabled by default
            Settings = new Dictionary<string, string>
            {
                { "endpoints", "http://localhost:2379" },
                { "keyPrefix", "/agileconfig" }
            }
        });

        // Register Consul plugin
        var consulLogger = loggerFactory.CreateLogger<ConsulSyncPlugin>();
        var consulPlugin = new ConsulSyncPlugin(consulLogger);
        syncEngine.RegisterPlugin(consulPlugin, new SyncPluginConfig
        {
            PluginName = "consul",
            Enabled = "false", // Disabled by default
            Settings = new Dictionary<string, string>
            {
                { "address", "http://localhost:8500" },
                { "keyPrefix", "agileconfig" }
            }
        });
    }
}
