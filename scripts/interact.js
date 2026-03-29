async function main() {
  const contractAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3";

  const [admin, user1] = await ethers.getSigners();

  const contract = await ethers.getContractAt("PredictionMarket", contractAddress);

  console.log("User placing prediction...");

  await contract.connect(user1).placePrediction(1, {
    value: ethers.parseEther("1")
  });

  console.log("Prediction placed!");

  console.log("Admin resolving market...");

  await contract.connect(admin).resolveMarket(1);

  console.log("Market resolved!");

  console.log("User claiming reward...");

  await contract.connect(user1).claimReward();

  console.log("Reward claimed!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
