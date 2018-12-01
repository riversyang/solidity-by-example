# Solidity 合约实例细节要点

## 投票（Ballot.sol）

构造函数：struct 的初始化、struct 数组的使用

giveRightToVote 函数：value 类型为 struct 的 mapping 的使用

delegate 函数：存储指针的使用、对 delegate 链的检查、对投票权重的实际计算

vote 函数：无效 proposal 时的执行效果

winningProposal、winnerName 函数：声明为 public view 将允许客户端在执行这两个函数时不需要发送交易，只需要从某个全节点上获取状态即可

可能的改进：modifier、投票时间的限制、giveRightToVote 函数可以考虑改为批量授权或者用所谓“白名单”的模式

## 简单的公开拍卖（SimpleAuction.sol）

注意事件的使用

第 71 行的逻辑，是考虑了多次出价的情况（理解 pendingReturns）

withdraw 函数并没有重入风险，因为 send 函数只会附加 2300 gas

## 暗拍卖（BlindAuction.sol）

注意 modifier 的使用

mapping 的 value 可以是一个 struct 数组，这是状态变量的特权

bid 函数：可以直接操作 mapping 中的 struct 数组

第 95 行的逻辑，是为了避免某用户反复调用 reveal 函数（通过多个交易），而不是为了避免重入，因为 reveal 函数中的转账用的是 transfer 函数，只会附加 2300 gas，没有重入的风险

placeBid、withdraw、auctionEnd 函数的逻辑与公开拍卖的逻辑基本一致

这个合约中的转账使用的是 transfer，如果调用 bid 函数的是合约地址，且相应的合约没有 payable 的 fallback 函数，transfer 就会失败（这只会影响特定的合约，所以这个问题并不属于当前这个合约的漏洞）

## 安全购买（Purchase.sol）

注意 modifier 的使用

注意构造函数中对偶数的检查方法

第 96、97 行任意一个转账失败，另一个转账也会失败

理解这个合约逻辑的设计：value 是实际的商品价格，合约由卖家创建，买卖双方都要先支付双倍 value 的金额到这个合约地址，在确认收货时，买家拿回 value，卖家拿回剩余金额

可能的改进：应该改为 withdraw 模式并增加确认收货的时限检查

## 微支付通道

### 支付签名承兑（ReceiverPays.sol）

这实际上是一个通过 off-chain 签名获得支付的类似于“支票承兑服务”的合约。

用于生成签名的 js 代码：

``` javascript
// recipient is the address that should be paid.
// amount, in wei, specifies how much ether should be sent.
// nonce can be any unique number to prevent replay attacks
// contractAddress is used to prevent cross-contract replay attacks
function signPayment(recipient, amount, nonce, contractAddress, callback) {
    var hash = "0x" + ethereumjs.ABI.soliditySHA3(
        ["address", "uint256", "uint256", "address"],
        [recipient, amount, nonce, contractAddress]
    ).toString("hex");

    web3.personal.sign(hash, web3.eth.defaultAccount, callback);
}
```

第 4 行的写法，和在构造函数中赋值的效果是一样的

第 15 行的逻辑，是与生成签名的 js 代码逻辑对应的

第 60 行计算时添加的固定字符串是以太坊客户端的逻辑

这是一个可以反复使用的用来兑现合约 owner 的付款签名数额的合约，直到合约 owner 调用 kill 函数。当然，也许增加一个 payable 的 fallback 函数会更好，这样就可以变成一个能够长期使用的 off-chain 付款签名承兑合约。

### 简单的支付通道（SimplePaymentChannel.sol）

用于生成签名的 js 代码：

``` javascript
function constructPaymentMessage(contractAddress, amount) {
    return ethereumjs.ABI.soliditySHA3(
        ["address", "uint256"],
        [contractAddress, amount]
    );
}

function signMessage(message, callback) {
    web3.personal.sign(
        "0x" + message.toString("hex"),
        web3.eth.defaultAccount,
        callback
    );
}

// contractAddress is used to prevent cross-contract replay attacks.
// amount, in wei, specifies how much Ether should be sent.

function signPayment(contractAddress, amount, callback) {
    var message = constructPaymentMessage(contractAddress, amount);
    signMessage(message, callback);
}
```

注意支付通道合约的逻辑：close 函数是由收款人调用的，所以收款金额是由收款人指定的。也就是说，收款人需要得到付款人针对这个最终付款数额的签名才能得到付款。这个签名是 off-chain 得到的，并且每次有新的收款时需要由付款人更新。

支付通道通常是临时性的，所以会有 expiration 的逻辑。
