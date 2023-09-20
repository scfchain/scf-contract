var WETH = artifacts.require("WFTC");
var FinswapFactory = artifacts.require("FinswapFactory");
var FinswapRouter = artifacts.require("FinswapRouter");
var Multicall2 = artifacts.require("Multicall2");

module.exports = async function(deployer, network, accounts) {
    
    var feeToSetter = accounts[0];
    var initCodeHash = "0xf301e7bb3b6c11c1d9ec3155aa16db5dfafdea975903e184ad76a07835715010";
    var WETH_ADDRESS = "";
    var FACTORY_ADDRESS = ""
    var Multicall2_ADDRESS = "";

    if (WETH_ADDRESS == "") {
        await deployer.deploy(WETH);
        console.log("WETH: ", WETH.address);
        WETH_ADDRESS = WETH.address;
    }

    if (Multicall2_ADDRESS == "") {
        await deployer.deploy(Multicall2);
        console.log("Multicall2: ", Multicall2.address);
        Multicall2_ADDRESS = Multicall2.address;
    }

    if (FACTORY_ADDRESS == "") {
        await deployer.deploy(FinswapFactory, feeToSetter);
        console.log("FinswapFactory: ", FinswapFactory.address);

        var factoryInstace = await FinswapFactory.deployed();
        var pairHash = await factoryInstace.pairCodeHash();
        if (pairHash != initCodeHash) {
            console.log("pairCodeHash not equal : ", pairHash);
            return;
        }
        FACTORY_ADDRESS = FinswapFactory.address;
    }
    
    await deployer.deploy(FinswapRouter, FACTORY_ADDRESS, WETH_ADDRESS);
    console.log("FinswapRouter: ", FinswapRouter.address);

    console.log("#####################  deploy done #####################");
    console.log("initCodeHash:", initCodeHash);
    console.log("WETH:", WETH_ADDRESS);
    console.log("Multicall:", Multicall2_ADDRESS);
    console.log("FinswapFactory:", FACTORY_ADDRESS);
    console.log("FinswapRouter:", FinswapRouter.address);
    console.log("#########################################################");
}
