import { expect } from "chai";
import { ethers } from "hardhat";

describe("CryptoVentures DAO – Governance Flow", function () {
  async function deployFixture() {
    const [admin, voter1, voter2, recipient] = await ethers.getSigners();

    /* ---------------- GovernanceVotes ---------------- */
    const Votes = await ethers.getContractFactory("GovernanceVotes");
    const votes = await Votes.deploy(
      "CryptoVentures DAO",
      "CVDAO",
      admin.address
    );
    await votes.waitForDeployment();

    /* ---------------- Timelock ---------------- */
    const minDelay = 2 * 24 * 60 * 60;

    const Timelock = await ethers.getContractFactory("GovernanceTimelock");
    const timelock = await Timelock.deploy(
      minDelay,
      [admin.address],
      [admin.address],
      admin.address
    );
    await timelock.waitForDeployment();

    /* ---------------- GovernanceCore ---------------- */
    const votingDelay = 1;
    const votingPeriod = 45818; // shortened for tests
    const quorumBps = 2000; // 20%
    const proposalThreshold = ethers.parseEther("100");

    const Gov = await ethers.getContractFactory("GovernanceCore");
    const governance = await Gov.deploy(
      await votes.getAddress(),
      admin.address,
      votingDelay,
      votingPeriod,
      quorumBps,
      proposalThreshold
    );
    await governance.waitForDeployment();

    /* ---------------- Treasury ---------------- */
    const Operational = await ethers.getContractFactory("OperationalTreasury");
    const treasury = await Operational.deploy(
      await timelock.getAddress(),
      ethers.parseEther("10")
    );
    await treasury.waitForDeployment();
    /* ---------------- Grant governor role to voters ---------------- */
const GOVERNOR_ROLE = await governance.GOVERNOR_ROLE();

await governance.grantRole(GOVERNOR_ROLE, voter1.address);
await governance.grantRole(GOVERNOR_ROLE, voter2.address);


    /* ---------------- Mint voting power ---------------- */
await votes.mint(admin.address, ethers.parseEther("200"));
await votes.mint(voter1.address, ethers.parseEther("100"));
await votes.mint(voter2.address, ethers.parseEther("100"));

/* ---------------- Delegate voting power ---------------- */
await votes.connect(admin).delegate(admin.address);
await votes.connect(voter1).delegate(voter1.address);
await votes.connect(voter2).delegate(voter2.address);

/* ---------------- Snapshot block ---------------- */
await ethers.provider.send("evm_mine", []);

    return {
      admin,
      voter1,
      voter2,
      recipient,
      votes,
      governance,
      timelock,
      treasury,
    };
  }

  it("runs full proposal → vote → queue → execute flow", async function () {
    const {
      admin,
      voter1,
      voter2,
      recipient,
      governance,
      treasury,
    } = await deployFixture();

    /* ---------------- Propose ---------------- */
    const tx = await governance.connect(admin).propose();
    const receipt = await tx.wait();

    const proposalId = receipt!.logs[0].args![0];

    /* ---------------- Move to voting ---------------- */
    await ethers.provider.send("evm_mine", []);
    await ethers.provider.send("evm_mine", []);

    /* ---------------- Vote ---------------- */
    await governance.connect(admin).castVote(proposalId, 1);
    await governance.connect(voter1).castVote(proposalId, 1);
    await governance.connect(voter2).castVote(proposalId, 0);

    /* ---------------- End voting ---------------- */
    for (let i = 0; i < 46000; i++) {
        await ethers.provider.send("evm_mine", []);
        }


    expect(await governance.state(proposalId)).to.equal(3); // Succeeded

    /* ---------------- Queue ---------------- */
    await governance.queue(proposalId);
    expect(await governance.state(proposalId)).to.equal(4); // Queued

    /* ---------------- Execute ---------------- */
    await governance.execute(proposalId);
    expect(await governance.state(proposalId)).to.equal(5); // Executed
  });

  it("prevents double voting", async function () {
    const { admin, governance } = await deployFixture();

    const tx = await governance.connect(admin).propose();
    const receipt = await tx.wait();
    const proposalId = receipt!.logs[0].args![0];

    await ethers.provider.send("evm_mine", []);
    await ethers.provider.send("evm_mine", []);

    await governance.connect(admin).castVote(proposalId, 1);

    await expect(
      governance.connect(admin).castVote(proposalId, 1)
    ).to.be.revertedWith("Gov: already voted");
  });
});
