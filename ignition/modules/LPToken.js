const {buildModule} = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("LPToken", (m)=>{
    const lpToken = m.contract("LPToken", ["0x1B00BC173Bb4d1459b464Af1F9B72967766E2fd3"]);

    return {lpToken};
});

