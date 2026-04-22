using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using AgileConfig.Client;

namespace AgileConfigWPFSample
{
    /// <summary>
    /// Interaction logic for App.xaml
    /// </summary>
    public partial class App : Application
    {
        public static ConfigClient ConfigClient { get; private set; }
        private void Application_Startup(object sender, StartupEventArgs e)
        {
            // Similar to a console project, decide how to obtain appId and related settings:
            // hard-code them, read from configuration, or fetch from another service.
            var appId = "test_app";
            var secret = "test_app";
            var nodes = "http://agileconfig-server.xbaby.xyz/";
            ConfigClient = new ConfigClient(appId, secret, nodes, "DEV");
            ConfigClient.Name = "wpfconfigclient";
            ConfigClient.Tag = "t1";
            ConfigClient.ConnectAsync().GetAwaiter();
        }
    }
}
