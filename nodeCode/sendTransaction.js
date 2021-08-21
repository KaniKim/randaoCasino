const Web3 = require("web3");
const web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545"));
const addressFrom = "0xF3250263460B841aa425f0e201c5C0094B8Ecece";
const privateKey = new Buffer.from("PRIVATE_KEY", "hex");