const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deployer:", deployer.address);

  // ENV ile örnek feed adresleri (gerçek ağda Chainlink feed adresleri)
  const chainlinkFeed = process.env.CHAINLINK_FEED || "0x0000000000000000000000000000000000000000";

  // 1) Medianizer
  const Median = await hre.ethers.getContractFactory("OracleLensMedian");
  // maxAge: 10 dk, outDecimals: 8, maxDeviation: %2.5 (250 bps)
  const median = await Median.deploy(600, 8, 250);
  await median.waitForDeployment();
  console.log("OracleLensMedian:", await median.getAddress());

  // 2) Chainlink adapter (opsiyonel)
  if (chainlinkFeed !== "0x0000000000000000000000000000000000000000") {
    const ChainA = await hre.ethers.getContractFactory("ChainlinkAdapter");
    const ch = await ChainA.deploy(chainlinkFeed);
    await ch.waitForDeployment();
    console.log("ChainlinkAdapter:", await ch.getAddress());

    await (await median.addSource(await ch.getAddress())).wait();
    console.log("Added Chainlink source");
  }

  // 3) Manuel kaynak (backup)
  const Manual = await hre.ethers.getContractFactory("ManualReporter");
  const manual = await Manual.deploy(100000000, 8); // 1.00000000 (örnek)
  await manual.waitForDeployment();
  console.log("ManualReporter:", await manual.getAddress());
  await (await median.addSource(await manual.getAddress())).wait();
  console.log("Added Manual source");

  // 4) Uniswap V2 TWAP adapter (yerelde mock pair gerekebilir)
  // const Uni = await hre.ethers.getContractFactory("UniV2TwapAdapter");
  // const uni = await Uni.deploy("0xPAIR_ADDRESS", true, 8);
  // await uni.waitForDeployment();
  // await (await median.addSource(await uni.getAddress())).wait();

  console.log("Deployment complete.");
}

main().catch((e) => { console.error(e); process.exitCode = 1; });
