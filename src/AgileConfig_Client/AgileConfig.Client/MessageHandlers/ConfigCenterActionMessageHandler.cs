using AgileConfig.Client.Utils;
using AgileConfig.Protocol;
using System;
using System.Collections.Generic;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace AgileConfig.Client.MessageHandlers
{
    /// <summary>
    /// Handler for action messages sent by the configuration server.
    /// </summary>
    class ConfigCenterActionMessageHandler
    {
        public static bool Hit(string message)
        {
            if (string.IsNullOrEmpty(message))
            {
                return false;
            }

            try
            {
                var action = JsonSerializer.Deserialize<ActionMessage>(message, MsJsonSerializerOption.Default);
                if (action == null)
                {
                    return false;
                }

                return action.Module == ActionModule.ConfigCenter;
            }
            catch 
            {
            }

            return false;
        }

        public static async Task Handle(string message, ConfigClient client)
        {
            var action = JsonSerializer.Deserialize<ActionMessage>(message, MsJsonSerializerOption.Default);
            if (action != null)
            {
                await client.TryHandleAction(action);
            }
        }
    }
}
