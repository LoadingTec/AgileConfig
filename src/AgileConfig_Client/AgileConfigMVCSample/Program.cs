using AgileConfig.Client;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Hosting;
using System;

namespace AgileConfigMVCSample
{
    public class Program
    {
        public static IConfigClient ConfigClient;

        public static void Main(string[] args)
        {
            CreateHostBuilder(args).Build().Run();
        }

        public static IHostBuilder CreateHostBuilder(string[] args) =>
            Host.CreateDefaultBuilder(args)
            .ConfigureAppConfiguration((context, config) =>
            {
                // Create a client instance.
                // The parameterless constructor automatically reads the AgileConfig section from appsettings.json.
                var configClient = new ConfigClient();
               
                // Register for configuration reload events.
                configClient.ReLoaded += (arg) =>
                {
                    foreach (var item in arg.NewConfigs)
                    {
                        Console.WriteLine($"{item.Key}={item.Value}");
                    }
                };

                // Add an AgileConfig-backed IConfigurationSource.
                config.AddAgileConfig(configClient);
            })
                .ConfigureWebHostDefaults(webBuilder =>
                {
                    webBuilder.UseStartup<Startup>();
                });

    }
}
