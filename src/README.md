# Contracts

Solidity contracts for the Base version of Spark DAO.

`TeachingRegistry.sol` now separates ordinary completion from two fault-contingent branches. Customer fault charges half of the locked lesson price and compensates the teacher for reserved time. Teacher fault charges half of the locked lesson price, returns the teacher bond, pays no teaching salary, records one remedial lesson owed, and can still distribute research-linked rewards for the affected and remedial lessons.

The hard research-share cap for teaching courses is 25%, which keeps the teacher-fault branch solvent when two research-linked lesson shares must be funded from a retained half-price payment.
