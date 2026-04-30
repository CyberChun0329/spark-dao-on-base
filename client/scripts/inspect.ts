import "dotenv/config";
import { loadClientConfigFromEnv } from "../src/config.js";
import {
  getDaoState,
  getResearchAsset,
  getResearchPosition,
} from "../src/research.js";
import {
  getTeachingRewardBuckets,
  getTeachingSessionSettlementLayers,
  getTeachingSessionState,
} from "../src/teaching.js";

async function main() {
  const config = loadClientConfigFromEnv();

  const assetId = process.env.INSPECT_ASSET_ID
    ? BigInt(process.env.INSPECT_ASSET_ID)
    : undefined;
  const positionId = process.env.INSPECT_POSITION_ID
    ? BigInt(process.env.INSPECT_POSITION_ID)
    : undefined;
  const teachingNftId = process.env.INSPECT_TEACHING_NFT_ID
    ? BigInt(process.env.INSPECT_TEACHING_NFT_ID)
    : undefined;

  const daoState = await getDaoState(config);
  console.log("daoState", daoState);

  if (assetId !== undefined) {
    console.log("researchAsset", await getResearchAsset(config, assetId));
  }

  if (assetId !== undefined && positionId !== undefined) {
    console.log(
      "researchPosition",
      await getResearchPosition(config, assetId, positionId),
    );
    console.log(
      "teachingRewardBuckets",
      await getTeachingRewardBuckets(config, assetId, positionId),
    );
  }

  if (teachingNftId !== undefined) {
    console.log(
      "teachingSessionState",
      await getTeachingSessionState(config, teachingNftId),
    );
    console.log(
      "teachingSettlementLayers",
      await getTeachingSessionSettlementLayers(config, teachingNftId),
    );
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
