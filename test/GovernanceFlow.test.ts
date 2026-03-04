import { expect } from "chai";
import { ethers } from "hardhat";

describe("CryptoVentures DAO – Full Functional Governance", function () {

  async function deployFixture() {
    const [admin, voter1, voter2, recipient] =
      await ethers.getSigners();

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
      [],
      [],
      admin.address
    );
    await timelock.waitForDeployment();

    /* ---------------- GovernanceCore ---------------- */
    const Gov = await ethers.getContractFactory("GovernanceCore");

    const governance = await Gov.deploy(
      await votes.getAddress(),
      await timelock.getAddress(),
      admin.address,
      1,          // votingDelay
      20,         // short voting period for tests
      1,       // quorumBps
      ethers.parseEther("100")
    );

    await governance.waitForDeployment();
    const GOVERNOR_ROLE = await governance.GOVERNOR_ROLE();

await governance.grantRole(GOVERNOR_ROLE, voter1.address);
await governance.grantRole(GOVERNOR_ROLE, voter2.address);
    /* ---- Grant timelock roles to governance ---- */
    const PROPOSER_ROLE = await timelock.PROPOSER_ROLE();
    const EXECUTOR_ROLE = await timelock.EXECUTOR_ROLE();

    await timelock.grantRole(PROPOSER_ROLE, await governance.getAddress());
    await timelock.grantRole(EXECUTOR_ROLE, ethers.ZeroAddress);

    /* ---------------- Treasury ---------------- */
    const Operational = await ethers.getContractFactory("OperationalTreasury");
    const treasury = await Operational.deploy(
      await timelock.getAddress(),
      ethers.parseEther("100")
    );
    await treasury.waitForDeployment();

    /* Fund treasury */
    await admin.sendTransaction({
      to: await treasury.getAddress(),
      value: ethers.parseEther("20"),
    });

    /* ---------------- Mint Voting Power ---------------- */
    await votes.mint(admin.address, ethers.parseEther("200"));
    await votes.mint(voter1.address, ethers.parseEther("100"));
    await votes.mint(voter2.address, ethers.parseEther("100"));

    await votes.connect(admin).delegate(admin.address);
    await votes.connect(voter1).delegate(voter1.address);
    await votes.connect(voter2).delegate(voter2.address);

    await ethers.provider.send("evm_mine", []);

    return {
      admin,
      voter1,
      voter2,
      recipient,
      governance,
      treasury,
      minDelay
    };
  }

  it("executes real ETH transfer through timelock", async function () {
    const {
      admin,
      voter1,
      voter2,
      recipient,
      governance,
      treasury,
      minDelay
    } = await deployFixture();

    const amount = ethers.parseEther("5");

    /* ✅ Correct function name */
    const calldata =
      treasury.interface.encodeFunctionData("transferETH", [
        recipient.address,
        amount
      ]);

    const tx = await governance.propose(
      [await treasury.getAddress()],
      [0],
      [calldata],
      "Transfer 5 ETH"
    );

    const receipt = await tx.wait();
    const proposalId = receipt!.logs[0].args![0];

    await ethers.provider.send("evm_mine", []);

    await governance.connect(admin).castVote(proposalId, 1);
    await governance.connect(voter1).castVote(proposalId, 1);
    await governance.connect(voter2).castVote(proposalId, 0);

    for (let i = 0; i < 25; i++) {
      await ethers.provider.send("evm_mine", []);
    }

    expect(await governance.state(proposalId)).to.equal(3); // Succeeded

    await governance.queue(proposalId);

    await expect(
      governance.execute(proposalId)
    ).to.be.reverted;

    await ethers.provider.send("evm_increaseTime", [minDelay]);
    await ethers.provider.send("evm_mine", []);

    const before = await ethers.provider.getBalance(recipient.address);

    await governance.execute(proposalId);

    const after = await ethers.provider.getBalance(recipient.address);

    expect(after - before).to.equal(amount);
  });

  it("uses non-linear sqrt voting", async function () {
    const { admin, governance, treasury } = await deployFixture();

    const calldata =
      treasury.interface.encodeFunctionData("transferETH", [
        admin.address,
        ethers.parseEther("1")
      ]);

    const tx = await governance.propose(
      [await treasury.getAddress()],
      [0],
      [calldata],
      "Sqrt Test"
    );

    const receipt = await tx.wait();
    const proposalId = receipt!.logs[0].args![0];

    await ethers.provider.send("evm_mine", []);

    await governance.connect(admin).castVote(proposalId, 1);

    const proposal = await governance.proposals(proposalId);

    // sqrt(200 ether) != 200 ether
    expect(proposal.forVotes).to.not.equal(ethers.parseEther("200"));
  });

  it("prevents double voting", async function () {
    const { admin, governance, treasury } = await deployFixture();

    const calldata =
      treasury.interface.encodeFunctionData("transferETH", [
        admin.address,
        ethers.parseEther("1")
      ]);

    const tx = await governance.propose(
      [await treasury.getAddress()],
      [0],
      [calldata],
      "Double Vote Test"
    );

    const receipt = await tx.wait();
    const proposalId = receipt!.logs[0].args![0];

    await ethers.provider.send("evm_mine", []);

    await governance.connect(admin).castVote(proposalId, 1);

    await expect(
      governance.connect(admin).castVote(proposalId, 1)
    ).to.be.revertedWith("Already voted");
  });

});