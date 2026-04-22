using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;

namespace AgileConfig.Client.MessageHandlers
{
    /// <summary>
    /// Handler for legacy heartbeat messages returned by the configuration server.
    /// </summary>
    class DropMessageHandler
    {
        public static bool Hit(string message)
        {
            return string.IsNullOrEmpty(message) || message == "0";
        }
    }
}
