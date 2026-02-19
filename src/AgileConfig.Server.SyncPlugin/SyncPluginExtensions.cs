using Microsoft.Extensions.DependencyInjection;
using AgileConfig.Server.SyncPlugin;

namespace AgileConfig.Server.SyncPlugin;

/// <summary>
/// Extension methods for registering SyncPlugin services
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
}
