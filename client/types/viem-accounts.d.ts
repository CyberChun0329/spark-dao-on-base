import type { Address, Hex } from "viem";

export function privateKeyToAccount(privateKey: Hex): { address: Address };
