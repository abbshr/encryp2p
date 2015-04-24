encryp2p
========

HIT 2015 Spring Cryptography Experiment 3-2

a P2P architecture based encrypted file shared system.

written in Ruby ❤.

## Encryp2p Under a Microscope

### 基础架构设计

#### 传输层协议
底层通讯基于TCP协议, 利用其可靠传输的特点完成上层通讯协议的设计.

#### Index
整个系统需要一个index节点, 用于提供共享数据的"目录", 它只保存获取数据的方法, 并不直接存储共享数据. 相当与P2P架构中的组长节点, 为peers提供索引服务.

#### Peers
作为直接的数据提供方, 以及主要使用者. peer即对等节点.

每个peer可以查阅index上的资源索引, 并通过文件名的方式请求下载, index会响应一份可用peer列表, 这些列表项都是其他peers之前发布的共享信息.

peer获取列表之后, 去和数据提供方建立另一个TCP连接, 通过ENCP协议完成加密数据传输.

### 加密通讯设计

在加密通讯上, 模拟了SSL/TLS加密HTTP协议的过程.

加密只发生在peer之间的通讯.

peer1向index请求文件, index返回可用peers的列表, 交由peer1的逻辑判断哪个节点可以获取指定文件. 当peer1成功与peer2建立TCP连接时, peer1向peer2发送`auth`报文, 包含CA为peer2颁发的数字证书, 以检验peer2身份, 即文件来源的可认证性.

成功后提取peer2的公钥, 并发送一系列同步报文: `sync_key`, `sync_iv`和`sync_hash`, 用于协商对称加密需要用的公钥, 初始向量, 以及散列算法.这些报文由peer2的提供的公钥加密发送至peer2.

peer2确认无误后, 返回ACK报文, 双方同步完成, peer1开始请求文件, peer2将原始数据进行AES-256-CBC加密, 并为其签名, 给peer1返回加密后的数据, 随后跟一个签名. peer1收到加密数据后, 用之前协商的对称密钥解密, 完成数据的加密. 并用数字签名校验传输过来的解密数据的完整性. 

以上过程无误, peer1保存文件, 否则断开连接, 尝试下一个可用对等节点.

### 数据交换格式

`encp.rb`中描述了通信协议的格式:

`head`是由一个UTF-8编码的JSON构成, 后接一个结束符`HEADEND\r\n`, 带外(out-of-bound)数据是一个Binary编码的数据, 最后跟一个全局结束符`DATAEND\r\n`

```
  HEADEND = "HEADEND\r\n"
  DATAEND = "DATAEND\r\n" 
  
  {
    "cmd" => "sync"
  }
  HEADEND\r\n
  \X03\X0A\XFF...
  DATAEND\r\n
```

head中的键值对表示控制信息, 也携带UTF-8编码的数据帧, 如果需要传输二进制数据, 则采用带外通信方式, 默认二进制处为空.

## HandBook

### 部署索引节点(index-server)

索引节点(index)作为CA是自签证的. 在初次启动前需要为其生成根证书并自签.

执行`index/ca.rb`脚本完成根证书颁发与签名, 将会在index目录下生成一个自签名的证书: `CA.cert`

__注:节点需要一个RSA私钥来完成证书签名以及对称密钥交换__

#### 生成RSA key pair

**需要本地OpenSSL库支持**

```sh
  # 强度为2048位的RSA私钥
  openssl genrsa -out CA.pem 2048
```

会在当前目录下生成CA.pem密钥对.

然后可以启动index: `ruby server.rb`, 默认监听2333端口

### 部署对等节点(peer)

对等设备仍需要一对RSA密钥.

启动守护进程`shared.rb`部署对等节点, 监听6666端口, 无需额外配置.

共享目录为`peer/share`  
下载目录为`peer/receive`

## Usage

启动encryp2p对等设备客户端: `ruby client.rb`

命令列表:

    INDEX-PEER PUBLIC COMMANDS HELP
    ===============
    registy - apply a cert from index
    push    - publish a shared file meta info to index
    pull    - download a shared file from peer
    list    - list all shared files
    
### 注册对等节点

共享文件之前, 需要`registy`命令向索引节点注册自己. 成功后会返回一个由index颁发的证书.

### 发布共享文件

`push`命令用于发布共享文件, 会提示输入文件名, 文件名是相对share的.

### 查看索引节点的共享文件列表

`list`命令会返回index中保存的共享信息

### 下载文件

`pull`命令允许下载指定文件名的文件, 至于和哪个对等节点建立连接则不可确定. 成功下载的文件会存入receive目录.
