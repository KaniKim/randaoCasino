const assert = require("assert");
const Web3 = require('web3');
const urlRPC = "http://127.0.0.1:8545"
const web3 = new Web3(new Web3.providers.HttpProvider(urlRPC));

web3.eth.getBalance("0xF3250263460B841aa425f0e201c5C0094B8Ecece", function(err, result) {
    if (err) {
        console.log(err);
    } else {
        console.log(web3.utils.fromWei(result, "ether") + "Ether");
    }
})