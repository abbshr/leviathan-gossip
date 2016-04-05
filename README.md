Leviathan-gossip
---

Leviathan 内部组件之一, 用于集群数据同步与最终一致性保障.

借鉴了Cassandra/Serf. 采用基于pull/push通信模型, scuttlebutt传输策略的gossip协议变种实现(即无分散key, 每个节点采用全冗余设计).

## API (当前版本)

```coffee
Gossip = require './'
gossip = new Gossip cfg

# 事件
gossip
  .on 'new_peers', (peers) ->
  .on 'updates', (deltas) ->

# 节点配置
cfg =
  id: 'node#0001' # 节点id
  seeds: ['192.168.1.3:2333', '10.0.169.2:2333'] # 种子节点
  addr: '192.168.110.1' # local
  port: 6666 # local
  gossip_val: 1000 # gossip 周期
  heartbeat_val: 1000 # 心跳计数周期
  health_check_val: 5 * 1000 # 节点健康检测周期
  reduce_val: 10 * 1000 # 空闲键回收周期
```
