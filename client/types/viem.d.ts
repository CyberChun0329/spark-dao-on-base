export type Address = `0x${string}`;
export type Hex = `0x${string}`;

export type Chain = {
  id: number;
  name: string;
  [key: string]: unknown;
};

export function http(rpcUrl?: string): unknown;

export function keccak256(value: Hex): Hex;

export function createPublicClient(params: { chain: Chain; transport: unknown }): unknown;

export function createWalletClient(params: {
  account: unknown;
  chain: Chain;
  transport: unknown;
}): unknown;
