using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using AgileConfig.Server.SyncPlugin.Plugins.Etcd;
using AgileConfig.Server.SyncPlugin.Contracts;

namespace AgileConfig.Server.SyncPlugin.BackgroundServices;

/// <summary>
/// Initializes SyncEngine and registers plugins on application startup
/// </summary>
public class SyncPluginInitializer : IHostedService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly SyncEngine _syncEngine;
    private readonly ILogger<SyncPluginInitializer> _logger;

    public SyncPluginInitializer(
        IServiceProvider serviceProvider,
        SyncEngine syncEngine,
        ILogger<SyncPluginInitializer> logger)
    {
        _serviceProvider = serviceProvider;
        _syncEngine = syncEngine;
        _logger = logger;
    }

    public async Task StartAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("Initializing SyncPlugin...");

        try
        {
            var loggerFactory = _serviceProvider.GetRequiredService<ILoggerFactory>();

            // Register built-in plugins
            RegisterBuiltInPlugins(_syncEngine, loggerFactory);

            // Initialize all registered plugins
            await _syncEngine.InitializeAsync();

            _logger.LogInformation("SyncPlugin initialized successfully");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to initialize SyncPlugin");
        }
    }

    private void RegisterBuiltInPlugins(SyncEngine syncEngine, ILoggerFactory loggerFactory)
    {
        // Register Etcd plugin
        try
        {
            var etcdLogger = loggerFactory.CreateLogger<EtcdSyncPlugin>();
            var etcdPlugin = new EtcdSyncPlugin(etcdLogger);
            syncEngine.RegisterPlugin(etcdPlugin, new SyncPluginConfig
            {
                PluginName = "etcd",
                Enabled = "false",
                Settings = new Dictionary<string, string>
                {
                    { "endpoints", "http://localhost:2379" },
                    { "keyPrefix", "/agileconfig" }
                }
            });
            _logger.LogInformation("Registered Etcd sync plugin");
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to register Etcd plugin (may not be referenced)");
        }
    }

    public Task StopAsync(CancellationToken cancellationToken)
    {
        return _syncEngine.ShutdownAsync();
    }
}
