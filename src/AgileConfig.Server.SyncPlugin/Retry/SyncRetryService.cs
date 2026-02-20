using Microsoft.Extensions.Logging;
using AgileConfig.Server.Data.Entity;
using AgileConfig.Server.IService;
using AgileConfig.Server.SyncPlugin.Models;

namespace AgileConfig.Server.SyncPlugin.Retry;

/// <summary>
/// Service that handles sync retry logic
/// Uses "replace all" strategy - always fetches latest configs from DB on retry
/// </summary>
public class SyncRetryService
{
    private readonly SyncEngine _syncEngine;
    private readonly IConfigService _configService;
    private readonly ILogger<SyncRetryService> _logger;
    private readonly List<FailedSyncRecord> _failedRecords = new();
    private readonly object _lock = new();

    // Configuration
    private const int MaxRetryCount = 10;
    private const int RetryIntervalSeconds = 30;

    public SyncRetryService(
        SyncEngine syncEngine,
        IConfigService configService,
        ILogger<SyncRetryService> logger)
    {
        _syncEngine = syncEngine;
        _configService = configService;
        _logger = logger;
    }

    /// <summary>
    /// Record a failed sync attempt
    /// </summary>
    public void RecordFailed(string appId, string env, string? errorMessage = null)
    {
        lock (_lock)
        {
            // Check if already exists
            var existing = _failedRecords.FirstOrDefault(x => x.AppId == appId && x.Env == env);
            
            if (existing != null)
            {
                existing.RetryCount++;
                existing.LastRetryTime = DateTimeOffset.UtcNow;
                existing.LastError = errorMessage;
                _logger.LogWarning("Sync failed for app {AppId} env {Env}, retry count: {Count}", 
                    appId, env, existing.RetryCount);
            }
            else
            {
                _failedRecords.Add(new FailedSyncRecord
                {
                    AppId = appId,
                    Env = env,
                    FailedTime = DateTimeOffset.UtcNow,
                    RetryCount = 1,
                    LastError = errorMessage
                });
                _logger.LogWarning("Recorded failed sync for app {AppId} env {Env}", appId, env);
            }
        }
    }

    /// <summary>
    /// Process all failed records - retry sync
    /// This should be called periodically by a background service
    /// </summary>
    public async Task ProcessFailedRecordsAsync()
    {
        List<FailedSyncRecord> recordsToProcess;
        
        lock (_lock)
        {
            // Get records that are ready to retry
            recordsToProcess = _failedRecords
                .Where(x => x.RetryCount < MaxRetryCount)
                .ToList();
        }

        if (!recordsToProcess.Any())
        {
            _logger.LogDebug("No failed sync records to process");
            return;
        }

        _logger.LogInformation("Processing {Count} failed sync records", recordsToProcess.Count);

        foreach (var record in recordsToProcess)
        {
            await RetrySyncAsync(record);
        }
    }

    /// <summary>
    /// Retry sync for a specific record
    /// Uses "replace all" strategy - fetches latest configs from DB
    /// </summary>
    private async Task RetrySyncAsync(FailedSyncRecord record)
    {
        try
        {
            _logger.LogInformation("Retrying sync for app {AppId} env {Env}, attempt {Attempt}", 
                record.AppId, record.Env, record.RetryCount);

            // Get latest configs from database
            var configs = await _configService.GetPublishedConfigsAsync(record.AppId, record.Env);
            
            if (configs == null || !configs.Any())
            {
                _logger.LogInformation("No configs found for app {AppId} env {Env}, removing failed record", 
                    record.AppId, record.Env);
                
                lock (_lock)
                {
                    _failedRecords.RemoveAll(x => x.AppId == record.AppId && x.Env == record.Env);
                }
                return;
            }

            // Convert to sync contexts
            var contexts = configs.Select(c => new SyncContext
            {
                AppId = c.AppId,
                AppName = c.AppId, // Use AppId as AppName
                Env = c.Env,
                Key = c.Key,
                Value = c.Value ?? "",
                Group = c.Group,
                OperationType = SyncOperationType.Add,
                Timestamp = DateTimeOffset.UtcNow
            }).ToArray();

            // Full sync
            var result = await _syncEngine.SyncAllAsync(contexts);

            if (result.Success)
            {
                _logger.LogInformation("Retry successful for app {AppId} env {Env}", record.AppId, record.Env);
                
                lock (_lock)
                {
                    _failedRecords.RemoveAll(x => x.AppId == record.AppId && x.Env == record.Env);
                }
            }
            else
            {
                _logger.LogWarning("Retry failed for app {AppId} env {Env}: {Error}", 
                    record.AppId, record.Env, result.Message);
                
                lock (_lock)
                {
                    var rec = _failedRecords.FirstOrDefault(x => x.AppId == record.AppId && x.Env == record.Env);
                    if (rec != null)
                    {
                        rec.LastError = result.Message;
                    }
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Exception during retry for app {AppId} env {Env}", record.AppId, record.Env);
        }
    }

    /// <summary>
    /// Get all failed records
    /// </summary>
    public List<FailedSyncRecord> GetFailedRecords()
    {
        lock (_lock)
        {
            return _failedRecords.ToList();
        }
    }

    /// <summary>
    /// Clear all failed records (for testing)
    /// </summary>
    public void ClearFailedRecords()
    {
        lock (_lock)
        {
            _failedRecords.Clear();
        }
    }
}
