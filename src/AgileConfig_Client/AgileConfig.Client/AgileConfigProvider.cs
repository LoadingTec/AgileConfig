using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using System;

namespace AgileConfig.Client
{
    public class AgileConfigProvider : ConfigurationProvider
    {
        private IConfigClient Client { get; }

        public AgileConfigProvider(IConfigClient client)
        {
            Client = client;
            Client.ReLoaded += (arg) =>
            {
                this.Data = Client.Data;
                this.OnReload();
            };
        }

        /// <summary>
        /// `Load` calls `ConfigClient.ConnectAsync`, which fetches all configuration after establishing the connection.
        /// </summary>
        public override void Load()
        {
            Client.ConnectAsync().GetAwaiter().GetResult() ;
            Data = Client.Data;
        }

    }
}
