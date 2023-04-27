const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log(
    "Deploying contracts with the account:",
    deployer.address
  );

  // Deploy ZeronToken
  const ZeronToken = await ethers.getContractFactory("ZeronToken");
  const znt = await ZeronToken.deploy();
  console.log("ZeronToken address:", znt.address);

  // Deploy ZeronRouter
  const ZeronV1Router = await ethers.getContractFactory("ZeronV1Router");
  const zeronV1Router = await ZeronV1Router.deploy();
  console.log("ZeronV1Router contract deployed to:", zeronV1Router.address);

  // Deploy ZeronArbitral
  const ZeronV1Arbitral = await ethers.getContractFactory("ZeronV1Arbitral");
  const zeronV1Arbitral = await ZeronV1Arbitral.deploy(zeronV1Router.address, znt.address);
  console.log("ZeronV1Arbitral contract deployed to:", zeronV1Arbitral.address);

  // Configure Arbitral address on ZeronV1Router
  await zeronV1Router.setArbitral(zeronV1Arbitral.address, { gasLimit: 1000000 });
  console.log("Arbitral address configured on ZeronV1Router contract");

  // 25% of ZNT tokens transferred to Arbitral contract.
  const transferAmount = ethers.utils.parseEther("250000000");
  await znt.transfer(zeronV1Arbitral.address, transferAmount);
  console.log("25% of ZNT tokens transferred to Arbitral contract.");
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
});
