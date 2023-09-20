### 安装开发环境

nodejs版本: v16.19

1. 安装truffle:

```shell
npm install -g truffle
```

2. 测试是否安装成功: `truffle version`

3. 在本目录执行 `npm i` 安装依赖

### 编译发布合约

1. 编辑`truffle-comfig.js`

将第`47`行的 `MNEMONIC` 赋值为发布合约的钱包私钥(不要带0x)，这个钱包里必须有链币做为手续费

将第`86`行的 `https://rpc.xx.com` 替换为自己的rpc地址

将第`87`行的`network_id`赋值为自己链的chainid

2. 发布合约

执行 `truffle deploy --network main`

发布完成后会输出`#####################  deploy done #####################`, 并输出合约地址，把输出的合约地址配置到前端项目的配置文件中，编译前端