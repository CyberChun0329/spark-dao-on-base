import "dotenv/config";
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import type { Address, Hex } from "viem";
import type { SparkDaoClientConfig } from "../src/config.js";
import type {
  SparkDaoClient,
  SparkDaoContractDescriptor,
} from "../src/createSparkDaoClient.js";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000" as Address;
const MANIFEST_SCHEMA = "spark-dao-module-compatibility/v1";

export type ContractKey =
  | "researchRegistry"
  | "teachingRegistry"
  | "teachingRewardDistributor"
  | "teachingPolicyGuard"
  | "teachingEconomicsPolicy"
  | "teachingFaultPolicy"
  | "researchPositionToken"
  | "teachingNftToken";

export type ManifestContract = {
  key: ContractKey;
  contractName: string;
  address: Address;
  artifact: string;
  deployedBytecodeHash?: Hex;
  artifactDeployedBytecodeHash?: Hex;
  immutableWiring?: Record<string, ContractKey | string>;
};

export type ModuleCompatibilityManifest = {
  schema: typeof MANIFEST_SCHEMA;
  chain: {
    name: string;
    chainId: number;
  };
  contracts: ManifestContract[];
  expectedRelationships: {
    teachingRegistry: {
      researchRegistry: ContractKey;
      rewardDistributor: ContractKey;
      policyGuard: ContractKey;
      economicsPolicy: ContractKey;
      faultPolicy: ContractKey;
    };
    teachingRewardDistributor: {
      teachingRegistry: ContractKey;
      researchRegistry: ContractKey;
    };
    policyVersions: {
      economics: number;
      fault: number;
    };
  };
};

export type ArtifactJson = {
  abi?: readonly unknown[];
  deployedBytecode?: {
    object?: string;
  };
};

type TeachingModuleState = readonly [
  Address,
  Address,
  Address,
  Address,
  Address,
  number,
  Address,
];

function normaliseAddress(value: Address): string {
  return value.toLowerCase();
}

function assertAddressMatch(label: string, actual: Address, expected: Address): void {
  if (normaliseAddress(actual) !== normaliseAddress(expected)) {
    throw new Error(`${label} mismatch: actual=${actual}, expected=${expected}`);
  }
}

function assertNumberMatch(label: string, actual: number, expected: number): void {
  if (actual !== expected) {
    throw new Error(`${label} mismatch: actual=${actual}, expected=${expected}`);
  }
}

function isAddress(value: string): value is Address {
  return /^0x[a-fA-F0-9]{40}$/.test(value);
}

function isHex(value: string): value is Hex {
  return /^0x[a-fA-F0-9]*$/.test(value);
}

function requireEnvNumber(name: string, fallback: number): number {
  const value = process.env[name];
  if (!value) return fallback;
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 0 || parsed > 255) {
    throw new Error(`${name} must be an integer between 0 and 255`);
  }
  return parsed;
}

function readJson(path: string): unknown {
  return JSON.parse(readFileSync(path, "utf8")) as unknown;
}

function manifestEntryByKey(
  manifest: ModuleCompatibilityManifest | undefined,
  key: ContractKey,
): ManifestContract | undefined {
  return manifest?.contracts.find((entry) => entry.key === key);
}

function loadManifest(): ModuleCompatibilityManifest | undefined {
  const manifestPath = process.env.MODULE_COMPATIBILITY_MANIFEST;
  if (!manifestPath) return undefined;
  const resolvedPath = resolve(manifestPath);
  return readJson(resolvedPath) as ModuleCompatibilityManifest;
}

async function validateManifest(
  manifest: ModuleCompatibilityManifest,
  options: { allowPlaceholderAddresses: boolean },
): Promise<void> {
  if (manifest.schema !== MANIFEST_SCHEMA) {
    throw new Error(`Unsupported manifest schema: ${manifest.schema}`);
  }
  if (!Number.isInteger(manifest.chain.chainId) || manifest.chain.chainId <= 0) {
    throw new Error("Manifest chain.chainId must be a positive integer");
  }
  if (!manifest.chain.name) {
    throw new Error("Manifest chain.name is required");
  }

  const seenKeys = new Set<ContractKey>();
  for (const entry of manifest.contracts) {
    if (seenKeys.has(entry.key)) {
      throw new Error(`Duplicate manifest contract key: ${entry.key}`);
    }
    seenKeys.add(entry.key);
    if (!entry.contractName) {
      throw new Error(`Manifest contract ${entry.key} is missing contractName`);
    }
    if (!entry.artifact.endsWith(".json")) {
      throw new Error(`Manifest contract ${entry.key} artifact must be a JSON file`);
    }
    if (!isAddress(entry.address)) {
      throw new Error(`Manifest contract ${entry.key} has invalid address: ${entry.address}`);
    }
    if (!options.allowPlaceholderAddresses && normaliseAddress(entry.address) === ZERO_ADDRESS) {
      throw new Error(`Manifest contract ${entry.key} still uses the zero-address placeholder`);
    }
    if (entry.deployedBytecodeHash && !isHex(entry.deployedBytecodeHash)) {
      throw new Error(`Manifest contract ${entry.key} has invalid deployedBytecodeHash`);
    }
    if (entry.artifactDeployedBytecodeHash && !isHex(entry.artifactDeployedBytecodeHash)) {
      throw new Error(`Manifest contract ${entry.key} has invalid artifactDeployedBytecodeHash`);
    }

    await validateArtifact(entry);
  }

  requireManifestKey(manifest, manifest.expectedRelationships.teachingRegistry.researchRegistry);
  requireManifestKey(manifest, manifest.expectedRelationships.teachingRegistry.rewardDistributor);
  requireManifestKey(manifest, manifest.expectedRelationships.teachingRegistry.policyGuard);
  requireManifestKey(manifest, manifest.expectedRelationships.teachingRegistry.economicsPolicy);
  requireManifestKey(manifest, manifest.expectedRelationships.teachingRegistry.faultPolicy);
  requireManifestKey(manifest, manifest.expectedRelationships.teachingRewardDistributor.teachingRegistry);
  requireManifestKey(manifest, manifest.expectedRelationships.teachingRewardDistributor.researchRegistry);
}

async function validateArtifact(entry: ManifestContract): Promise<void> {
  if (!entry.artifactDeployedBytecodeHash) return;

  const artifactPath = resolve(entry.artifact);
  if (!existsSync(artifactPath)) {
    throw new Error(`Manifest contract ${entry.key} artifact does not exist: ${entry.artifact}`);
  }

  const artifact = readJson(artifactPath) as ArtifactJson;
  const deployedBytecode = normaliseBytecode(artifact.deployedBytecode?.object);
  if (!deployedBytecode) {
    throw new Error(`Manifest contract ${entry.key} artifact has no deployed bytecode`);
  }

  const actualHash = await hashBytecode(deployedBytecode);
  assertHashMatch(
    `${entry.key} artifact deployed bytecode hash`,
    actualHash,
    entry.artifactDeployedBytecodeHash,
  );
}

function requireManifestKey(manifest: ModuleCompatibilityManifest, key: ContractKey): void {
  if (!manifest.contracts.some((entry) => entry.key === key)) {
    throw new Error(`Manifest relationship references missing contract key: ${key}`);
  }
}

function normaliseBytecode(bytecode: string | undefined): Hex | undefined {
  if (!bytecode || bytecode === "0x") return undefined;
  const prefixed = bytecode.startsWith("0x") ? bytecode : `0x${bytecode}`;
  if (!isHex(prefixed)) {
    throw new Error("Invalid bytecode hex");
  }
  return prefixed;
}

function assertHashMatch(label: string, actual: Hex, expected: Hex): void {
  if (actual.toLowerCase() !== expected.toLowerCase()) {
    throw new Error(`${label} mismatch: actual=${actual}, expected=${expected}`);
  }
}

async function hashBytecode(bytecode: Hex): Promise<Hex> {
  const { keccak256 } = await import("viem");
  return keccak256(bytecode);
}

function contractByKey(client: SparkDaoClient, key: ContractKey): SparkDaoContractDescriptor | undefined {
  return client.contracts[key];
}

function addressByKey(config: SparkDaoClientConfig, key: ContractKey): Address | undefined {
  return config.addresses[key];
}

export function expectedAddressByKey(
  config: SparkDaoClientConfig,
  manifest: ModuleCompatibilityManifest | undefined,
  key: ContractKey,
): Address | undefined {
  return addressByKey(config, key) ?? manifestEntryByKey(manifest, key)?.address;
}

export function contractDescriptorFromArtifact(
  entry: ManifestContract,
  artifact: ArtifactJson,
): SparkDaoContractDescriptor {
  if (!Array.isArray(artifact.abi)) {
    throw new Error(`Manifest contract ${entry.key} artifact has no ABI`);
  }
  return {
    address: entry.address,
    abi: artifact.abi,
  };
}

function contractDescriptorFromManifestEntry(entry: ManifestContract): SparkDaoContractDescriptor {
  return contractDescriptorFromArtifact(entry, readJson(resolve(entry.artifact)) as ArtifactJson);
}

function contractByKeyOrManifest(
  client: SparkDaoClient,
  manifest: ModuleCompatibilityManifest | undefined,
  key: ContractKey,
): SparkDaoContractDescriptor | undefined {
  const configuredContract = contractByKey(client, key);
  if (configuredContract) return configuredContract;
  const manifestEntry = manifestEntryByKey(manifest, key);
  return manifestEntry ? contractDescriptorFromManifestEntry(manifestEntry) : undefined;
}

function requireContract(
  client: SparkDaoClient,
  key: ContractKey,
  envName: string,
): SparkDaoContractDescriptor {
  const contract = contractByKey(client, key);
  if (!contract) {
    throw new Error(`${envName} is required for module compatibility checks`);
  }
  return contract;
}

async function readAddress(
  client: SparkDaoClient,
  contract: SparkDaoContractDescriptor,
  functionName: string,
): Promise<Address> {
  return (await client.publicClient.readContract({
    ...contract,
    functionName,
  })) as Address;
}

async function readVersion(
  client: SparkDaoClient,
  contract: SparkDaoContractDescriptor,
  functionName: string,
  args?: readonly unknown[],
): Promise<number> {
  return Number(
    await client.publicClient.readContract({
      ...contract,
      functionName,
      args,
    }),
  );
}

async function readBool(
  client: SparkDaoClient,
  contract: SparkDaoContractDescriptor,
  functionName: string,
): Promise<boolean> {
  return (await client.publicClient.readContract({
    ...contract,
    functionName,
  })) as boolean;
}

function expectedVersions(manifest?: ModuleCompatibilityManifest) {
  return {
    economics:
      manifest?.expectedRelationships.policyVersions.economics
      ?? requireEnvNumber("EXPECTED_TEACHING_ECONOMICS_POLICY_VERSION", 1),
    fault:
      manifest?.expectedRelationships.policyVersions.fault
      ?? requireEnvNumber("EXPECTED_TEACHING_FAULT_POLICY_VERSION", 1),
  };
}

async function checkOnchainCompatibility(
  config: SparkDaoClientConfig,
  client: SparkDaoClient,
  manifest?: ModuleCompatibilityManifest,
): Promise<void> {
  const distributor = requireContract(
    client,
    "teachingRewardDistributor",
    "TEACHING_REWARD_DISTRIBUTOR",
  );
  const policyGuard = requireContract(client, "teachingPolicyGuard", "TEACHING_POLICY_GUARD");
  const economicsPolicy = requireContract(
    client,
    "teachingEconomicsPolicy",
    "TEACHING_ECONOMICS_POLICY",
  );
  const faultPolicy = requireContract(client, "teachingFaultPolicy", "TEACHING_FAULT_POLICY");

  const [
    moduleResearchRegistry,
    moduleTeachingNftToken,
    modulePolicyGuard,
    moduleEconomicsPolicy,
    moduleFaultPolicy,
    moduleFaultVersion,
    moduleRewardDistributor,
  ] = (await client.publicClient.readContract({
    ...client.contracts.teachingRegistry,
    functionName: "getTeachingModuleState",
  })) as TeachingModuleState;

  assertAddressMatch(
    "registry module research registry",
    moduleResearchRegistry,
    config.addresses.researchRegistry,
  );
  assertAddressMatch("registry module policy guard", modulePolicyGuard, policyGuard.address);
  assertAddressMatch(
    "registry module economics policy",
    moduleEconomicsPolicy,
    economicsPolicy.address,
  );
  assertAddressMatch("registry module fault policy", moduleFaultPolicy, faultPolicy.address);
  assertAddressMatch(
    "registry module reward distributor",
    moduleRewardDistributor,
    distributor.address,
  );
  const expectedTeachingNftToken = expectedAddressByKey(config, manifest, "teachingNftToken");
  if (expectedTeachingNftToken) {
    assertAddressMatch(
      "registry module teaching NFT token",
      moduleTeachingNftToken,
      expectedTeachingNftToken,
    );
  }

  const distributorTeachingRegistry = await readAddress(client, distributor, "TEACHING_REGISTRY");
  const distributorResearchRegistry = await readAddress(client, distributor, "RESEARCH_REGISTRY");
  assertAddressMatch(
    "distributor TEACHING_REGISTRY",
    distributorTeachingRegistry,
    config.addresses.teachingRegistry,
  );
  assertAddressMatch(
    "distributor RESEARCH_REGISTRY",
    distributorResearchRegistry,
    config.addresses.researchRegistry,
  );

  const versions = expectedVersions(manifest);
  const economicsVersion = await readVersion(
    client,
    economicsPolicy,
    "TEACHING_ECONOMICS_POLICY_VERSION",
  );
  const faultVersion = await readVersion(client, faultPolicy, "FAULT_POLICY_VERSION");
  const guardEconomicsVersion = await readVersion(
    client,
    policyGuard,
    "validateEconomicsPolicy",
    [economicsPolicy.address],
  );
  const guardFaultVersion = await readVersion(client, policyGuard, "validatePolicy", [
    faultPolicy.address,
  ]);

  assertNumberMatch("economics policy version", economicsVersion, versions.economics);
  assertNumberMatch("policy guard economics validation version", guardEconomicsVersion, versions.economics);
  assertNumberMatch("fault policy version", faultVersion, versions.fault);
  assertNumberMatch("policy guard fault validation version", guardFaultVersion, versions.fault);
  assertNumberMatch("registry module fault policy version", moduleFaultVersion, versions.fault);

  await checkTokenMinterLocks(client, manifest, "researchPositionToken", "research position token");
  await checkTokenMinterLocks(client, manifest, "teachingNftToken", "teaching NFT token");

  if (manifest) {
    await checkManifestAgainstChain(config, client, manifest);
  }
}

async function checkTokenMinterLocks(
  client: SparkDaoClient,
  manifest: ModuleCompatibilityManifest | undefined,
  key: "researchPositionToken" | "teachingNftToken",
  label: string,
): Promise<void> {
  const token = contractByKeyOrManifest(client, manifest, key);
  if (!token) return;
  const minterLocked = await readBool(client, token, "minterLocked");
  if (!minterLocked) {
    throw new Error(`${label} minter is not locked`);
  }
}

async function checkManifestAgainstChain(
  config: SparkDaoClientConfig,
  client: SparkDaoClient,
  manifest: ModuleCompatibilityManifest,
): Promise<void> {
  assertNumberMatch("manifest chainId", manifest.chain.chainId, config.chain.id);

  for (const entry of manifest.contracts) {
    const configuredAddress = addressByKey(config, entry.key);
    if (configuredAddress) {
      assertAddressMatch(`manifest ${entry.key} address`, entry.address, configuredAddress);
    }

    if (entry.deployedBytecodeHash) {
      const bytecode = await client.publicClient.getBytecode({ address: entry.address });
      if (!bytecode) {
        throw new Error(`No deployed bytecode found for ${entry.key} at ${entry.address}`);
      }
      const deployedHash = await hashBytecode(bytecode);
      assertHashMatch(`${entry.key} deployed bytecode hash`, deployedHash, entry.deployedBytecodeHash);
    }
  }
}

async function main(): Promise<void> {
  const manifest = loadManifest();
  const validateManifestOnly = process.env.MODULE_COMPATIBILITY_VALIDATE_MANIFEST_ONLY === "1";

  if (manifest) {
    await validateManifest(manifest, { allowPlaceholderAddresses: validateManifestOnly });
  }

  if (validateManifestOnly) {
    if (!manifest) {
      throw new Error("MODULE_COMPATIBILITY_MANIFEST is required in validate-only mode");
    }
    console.log("Module compatibility manifest static check passed");
    return;
  }

  const [{ loadClientConfigFromEnv }, { createSparkDaoClient }] = await Promise.all([
    import("../src/config.js"),
    import("../src/createSparkDaoClient.js"),
  ]);
  const config = loadClientConfigFromEnv();
  const client = createSparkDaoClient({
    rpcUrl: config.rpcUrl,
    chain: config.chain,
    addresses: config.addresses,
  });
  await checkOnchainCompatibility(config, client, manifest);
  console.log("Module compatibility checks passed");
}

const executedPath = process.argv[1] ? pathToFileURL(resolve(process.argv[1])).href : undefined;
if (import.meta.url === executedPath) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
