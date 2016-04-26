Leviathan-gossip
---

Leviathan 内部组件之一, 用于构建 Leviathan 集群, 提供数据同步与最终一致性保障.

借鉴了 Cassandra/Serf. 采用基于 pull/push 传输模型, scuttlebutt(scuttle-depth) 传输策略的 gossip(Anti-Entropy) 协议实现.

## TODO

+ 设计实现key同步删除
+ 优化健康检测模块的计量可信度

## Examples

https://github.com/abbshr/leviathan-gossip/tree/master/example

```bash
# 打开四个控制台启动四个节点, (其中1和4为种子节点), 观察输出变化
coffee peer_${i}.coffee
```

## API (当前版本)

```coffee
Gossip = require 'leviathan-gossip'
gossip = new Gossip cfg

# 事件
gossip
  .on 'peers_discover', (peers) ->
    # 发现新节点
  .on 'peers_recover', (peers) ->
    # 恢复健康状态的节点
  .on 'peers_suspend', (peers) ->
    # 进入可疑状态的节点
  .on 'updates', (deltas) ->
    # 获取状态更新
    # 写入持久化存储
    # persistent_storage.write deltas
  
  # .on 'delete', (key) ->

# 节点配置
cfg =
  alias: 'node#0001' # 节点注释
  seeds: ['192.168.1.3:2333', '10.0.169.2:2333'] # 种子节点
  addr: '192.168.110.1' # 使用外部节点可达地址
  port: 6666 # 服务端口
  gossip_val: 1000 # gossip 周期
  heartbeat_val: 1000 # 心跳计数周期
  health_check_val: 5 * 1000 # 节点健康检测周期
  # reduce_val: 10 * 1000 # 空闲键回收周期

# 数据操作
gossip.set k, v # 写本地节点
gossip.get r, k # → value
gossip.getn r, k # → version
# gossip.del k

###
  可以按照不同的设计思路设计k-v增量版本生成器, 默认采用从0开始递增的版本
  本地set操作自增产生增量版本
###
```

## 参考与引用

+ [SWIM: Scalable Weakly-consistent Infection-style Process Group Membership](https://www.cs.cornell.edu/~asdas/research/dsn02-swim.pdf)
+ [Efficient Reconciliation and Flow Control for Anti-Entropy Protocols](http://www.cs.cornell.edu/home/rvr/papers/flowgossip.pdf)
+ [Cassandra: a decentralized structured storage system](http://www.cl.cam.ac.uk/~ey204/teaching/ACS/R212_2014_2015/papers/lakshman_ladis_2009.pdf)
+ [Serf internal](https://www.serfdom.io/docs/internals/gossip.html)
+ [Using Gossip Protocols For Failure Detection, Monitoring, Messaging And Other Good Things](http://highscalability.com/blog/2011/11/14/using-gossip-protocols-for-failure-detection-monitoring-mess.html)
+ [Gossip protocols for
large-scale distributed systems](http://sbrc2010.inf.ufrgs.br/resources/presentations/tutorial/tutorial-montresor.pdf)
+ [A Scuttlebutt Demo](http://awinterman.github.io/simple-scuttle/)
+ [scuttlebutt-gossip-protocol](https://distributedalgorithm.wordpress.com/2014/05/15/scuttlebutt-gossip-protocol/)
+ [The φ Accrual Failure Detector](http://www.jaist.ac.jp/~defago/files/pdf/IS_RR_2004_010.pdf)
