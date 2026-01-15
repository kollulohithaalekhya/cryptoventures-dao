import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying with:", deployer.address);

  /*//////////////////////////////////////////////////////////////
                        GOVERNANCE TOKEN
  //////////////////////////////////////////////////////////////*/

  const Votes = await ethers.getContractFactory("GovernanceVotes");
  const votes = await Votes.deploy(
    "CryptoVentures DAO",
    "CVDAO",
    deployer.address
  );
  await votes.waitForDeployment();

  console.log("GovernanceVotes:", await votes.getAddress());

  /*//////////////////////////////////////////////////////////////
                          TIMELOCK
  //////////////////////////////////////////////////////////////*/

  const minDelay = 2 * 24 * 60 * 60;

  const Timelock = await ethers.getContractFactory("GovernanceTimelock");
  const timelock = await Timelock.deploy(
    minDelay,
    [deployer.address],
    [deployer.address],
    deployer.address
  );
  await timelock.waitForDeployment();

  console.log("Timelock:", await timelock.getAddress());

  /*//////////////////////////////////////////////////////////////
                        GOVERNANCE CORE
  //////////////////////////////////////////////////////////////*/

  const votingDelay = 1;
  const votingPeriod = 45818;
  const quorumBps = 2000;
  const proposalThreshold = ethers.parseEther("100");

  const Gov = await ethers.getContractFactory("GovernanceCore");
  const governance = await Gov.deploy(
    await votes.getAddress(),
    deployer.address,
    votingDelay,
    votingPeriod,
    quorumBps,
    proposalThreshold
  );
  await governance.waitForDeployment();

  console.log("GovernanceCore:", await governance.getAddress());

  /*//////////////////////////////////////////////////////////////
                        TREASURIES
  //////////////////////////////////////////////////////////////*/

  const Operational = await ethers.getContractFactory("OperationalTreasury");
  const operational = await Operational.deploy(
    await timelock.getAddress(),
    ethers.parseEther("10")
  );
  await operational.waitForDeployment();

  console.log("OperationalTreasury:", await operational.getAddress());

  const Investment = await ethers.getContractFactory("InvestmentTreasury");
  const investment = await Investment.deploy(
    await timelock.getAddress(),
    ethers.parseEther("100")
  );
  await investment.waitForDeployment();

  console.log("InvestmentTreasury:", await investment.getAddress());

  const Reserve = await ethers.getContractFactory("ReserveTreasury");
  const reserve = await Reserve.deploy(await timelock.getAddress());
  await reserve.waitForDeployment();

  console.log("ReserveTreasury:", await reserve.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
