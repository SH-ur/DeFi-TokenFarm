const {buildModule} = require("@nomicfoundation/hardhat-ignition/modules");

const DAppTokenModule = buildModule("DAppToken", (m)=>{
    const dappToken = m.contract("DAppToken", ["0x1B00BC173Bb4d1459b464Af1F9B72967766E2fd3"]);

    return {dappToken};
});

module.exports = DAppTokenModule;