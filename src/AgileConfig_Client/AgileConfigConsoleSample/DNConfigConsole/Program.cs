using AgileConfig.Client;
// using Modules;

// See https://aka.ms/new-console-template for more information
Console.WriteLine("Hello, World!");
//接入配置中心：VSCApp/666666  http://192.168.201.139:5000/ui#/app

//控制台、类库项目，不一定有appsettngs.json文件，所以使用ConfigClient的有参构造函数手动传入appid等参数
//如果控制台项目同样建立了appsettings.json文件，那么同样可以跟mvc项目一样使用无参构造函数让Client自动读取appid等配置
var appId = "test_app";
var secret = "test_app";
var nodes =  "http://192.168.205.134:8050/";
//使用有参构造函数，手动传入appid等信息
var client = new ConfigClient(appId, secret, nodes, "DEV");
_ = Task.Run(async () =>
{
    while (true)
    {
        await Task.Delay(5000);
        foreach (string key in client.Data.Keys)
        {
            var val = client[key];
            Console.WriteLine("{0} : {1}", key, val);
        }
    }
});

await client.ConnectAsync();//如果不是mvc项目，不使用AddAgileConfig方法的话，需要手动调用ConnectAsync方法来跟服务器建立连接
Console.WriteLine("Test started .");

// AlarmAndNotificationManager alarmMessage = new AlarmAndNotificationManager();
// alarmMessage.SendAlarm("Hello Manager Message....");
Console.Read();