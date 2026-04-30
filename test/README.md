# Tests

Foundry tests for the Base implementation.

`TeachingRegistry.t.sol` covers ordinary teaching completion, coordinator-forced valid settlement, customer-fault half-price settlement, teacher-fault remedial settlement, and research-linked reward distribution under fault conditions.

`TeachingGasCalibration.t.sol` writes the measured gas table used by the cost simulation. It includes ordinary, forced-valid, customer-fault, and teacher-fault paths across no-research, zero-share, research-backed, weighted multi-asset, and multi-layer settings.

`ResearchGasCalibration.t.sol` writes the measured research-maintenance gas table used by the same simulation. It covers main asset creation, current and prepared patch positions, layer sealing, early-decay approval, and layer advancement.
