import "dotenv/config";
import { loadClientConfigFromEnv } from "../src/config.js";
import {
  getResearchDaoState,
  getResearchAsset,
  getResearchPosition,
} from "../src/research.js";
import {
  getTeachingDaoState,
  getTeachingModuleState,
  getTeachingRewardPreview,
  getTeachingSeat,
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
  const seatIndex = process.env.INSPECT_SEAT_INDEX
    ? Number(process.env.INSPECT_SEAT_INDEX)
    : undefined;

  console.log("researchDaoState", await getResearchDaoState(config));
  console.log("teachingDaoState", await getTeachingDaoState(config));
  console.log("teachingModuleState", await getTeachingModuleState(config));

  if (assetId !== undefined) {
    console.log("researchAsset", await getResearchAsset(config, assetId));
  }

  if (assetId !== undefined && positionId !== undefined) {
    console.log(
      "researchPosition",
      await getResearchPosition(config, assetId, positionId),
    );
    if (teachingNftId !== undefined) {
      console.log(
        "teachingRewardPreview",
        await getTeachingRewardPreview(config, teachingNftId, assetId, positionId),
      );
    }
  }

  if (teachingNftId !== undefined) {
    console.log("teachingState", await getTeachingSessionState(config, teachingNftId));
    if (seatIndex !== undefined) {
      console.log("teachingSeat", await getTeachingSeat(config, teachingNftId, seatIndex));
    }
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
