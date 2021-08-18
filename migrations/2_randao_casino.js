const randaoCasino = artifacts.require("Casino");

module.exports = function(deployer) {
    deployer.deploy(randaoCasino, web3.utils.toBN("1e18"), "3");
};