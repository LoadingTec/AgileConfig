using AgileConfig.Server.Common.EventBus;
using AgileConfig.Server.Data.Entity;
using AgileConfig.Server.Event;
using AgileConfig.Server.IService;
using AgileConfig.Server.SyncPlugin;
using AgileConfig.Server.SyncPlugin.Models;

namespace AgileConfig.Server.EventHandler;

/// <summary>
/// Event handler that syncs published configs to external systems via SyncPlugin
/// </summary>
public class ConfigSyncEventHandler : IEventHandler<PublishConfigSuccessful>
{
    private readonly IConfigService _configService;
    private readonly SyncEngine _syncEngine;
    private readonly Microsoft.Extensions.Logging.ILogger<ConfigSyncEventHandler> _logger;

    public ConfigSyncEventHandler(
        IConfigService configService,
        SyncEngine syncEngine,
        Microsoft.Extensions.Logging.ILogger<ConfigSyncEventHandler> logger)
    {
        _configService = configService;
        _syncEngine = syncEngine;
        _logger = logger;
    }

    public async Task Handle(IEvent evt)
    {
        var evtInstance = evt as PublishConfigSuccessful;
        var timeline = evtInstance.PublishTimeline;
        
        if (timeline == null)
        {
            _logger.LogWarning("PublishConfigSuccessful event has no timeline");
            return;
        }

        try
        {
            // Get all published configs for this app and env
            var configs = await _configService.GetPublishedConfigsAsync(timeline.AppId, timeline.Env);
            
            if (configs == null || !configs.Any())
            {
                _logger.LogInformation("No published configs found for app {AppId} env {Env}", timeline.AppId, timeline.Env);
                return;
            }

            // Convert to sync contexts
            var contexts = configs.Select(c => new SyncContext
            {
                AppId = c.AppId,
                AppName = c.AppName ?? "",
                Env = c.Env,
                Key = c.Key,
                Value = c.Value ?? "",
                Group = c.GroupName,
                OperationType = SyncOperationType.Add,
                Timestamp = DateTimeOffset.UtcNow
            }).ToList();

            // Batch sync to all enabled plugins
            var result = await _syncEngine.SyncBatchAsync(contexts);
            
            if (result.Success)
            {
                _logger.LogInformation("Successfully synced {Count} configs for app {AppId} env {Env}", 
                    contexts.Count, timeline.AppId, timeline.Env);
            }
            else
            {
                _logger.LogWarning("Failed to sync configs for app {AppId} env {Env}: {Message}", 
                    timeline.AppId, timeline.Env, result.Message);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Exception during config sync for app {AppId} env {Env}", 
                timeline.AppId, timeline.Env);
        }
    }
}

/// <summary>
/// Event handler that syncs deleted configs to external systems
/// </summary>
public class ConfigDeleteSyncEventHandler : IEventHandler<DeleteConfigSuccessful>
{
    private readonly IConfigService _configService;
    private readonly SyncEngine _syncEngine;
    private readonly Microsoft.Extensions.Logging.ILogger<ConfigDeleteSyncEventHandler> _logger;

    public ConfigDeleteSyncEventHandler(
        IConfigService configService,
        SyncEngine syncEngine,
        Microsoft.Extensions.Logging.ILogger<ConfigDeleteSyncEventHandler> logger)
    {
        _configService = configService;
        _syncEngine = syncEngine;
        _logger = logger;
    }

    public async Task Handle(IEvent evt)
    {
        var evtInstance = evt as DeleteConfigSuccessful;
        
        try
        {
            var context = new SyncContext
            {
                AppId = evtInstance.Config.AppId,
                AppName = evtInstance.Config.AppName ?? "",
                Env = evtInstance.Config.Env,
                Key = evtInstance.Config.Key,
                Value = "",
                Group = evtInstance.Config.GroupName,
                OperationType = SyncOperationType.Delete,
                Timestamp = DateTimeOffset.UtcNow
            };

            var result = await _syncEngine.DeleteAsync(context);
            
            if (result.Success)
            {
                _logger.LogInformation("Successfully deleted config {Key} from sync plugins", context.Key);
            }
            else
            {
                _logger.LogWarning("Failed to delete config {Key} from sync plugins: {Message}", 
                    context.Key, result.Message);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Exception during config delete sync");
        }
    }
}
