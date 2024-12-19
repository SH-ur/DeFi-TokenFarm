const {buildModule} = require("@nomicfoundation/hardhat-ignition/modules");

const TokenFarm = buildModule("TokenFarm", (m)=>{
    const tokenFarm = buildModule("TokenFarm", []);

    return {tokenFarm};
});

module.exports = TokenFarm;