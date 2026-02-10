async function main() {
  const contractAddress = "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0";

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
