using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;

namespace AgileConfig.Client.MessageHandlers
{
    /// <summary>
    /// Handler for legacy heartbeat responses from the configuration server.
    /// </summary>
    class OldConfigPingRetrunMessageHandler
    {
        public static bool Hit(string message)
        {
            if (string.IsNullOrEmpty(message))
            {
                return false;
            }

            return message.StartsWith("V:");
        }

        public static async Task Handle(string message, ConfigClient client)
        {
            var version = message.Substring(2, message.Length - 2);
            var localVersion = client.DataMd5Version();
            if (version != localVersion)
            {
                // Reload everything when the server version differs from the local copy.
                await client.Load();
            }
        }
    }
}
