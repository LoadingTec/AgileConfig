function FindProxyForURL(url, host) {
  // 替换 192.168.201.51 与 10809 为实际对客户端可见的地址与 v2ray HTTP 入站端口
  return "PROXY 192.168.201.51:10809; DIRECT";
}
