const CompTest = artifacts.require("CompTest");

const kovanDAI = "0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa";
const kovan_cDAI = "0xf0d0eb522cfa50b716b3b1604c4f0fa6f04376ad";

module.exports = (deployer) => {
  deployer.deploy(CompTest, kovanDAI, kovan_cDAI);
};