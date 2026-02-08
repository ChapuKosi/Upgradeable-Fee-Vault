todo :

generate natspec documentation

## 📝 How to Present This

### On Resume:
```
Upgradeable Fee Vault (Solidity, Foundry)
- Implemented UUPS proxy pattern with Diamond storage for safe contract upgrades
- Designed V1→V2 migration preserving state while adding security features
- 7 comprehensive tests covering upgrade safety and feature correctness
- Technologies: Solidity 0.8.30, Foundry, OpenZeppelin, ERC1967
```

### On GitHub:
- Pin this repo
- Add topics: `solidity`, `upgradeable-contracts`, `uups`, `foundry`, `diamond-storage`
- Ensure README has clear diagrams and code examples

### In Interviews:
- Lead with storage pattern expertise
- Explain why Diamond storage > traditional
- Walk through upgrade process
- Highlight test coverage


**Q: "How do you prevent storage collisions in upgradeable contracts?"**
> "I use Diamond storage pattern - a namespaced approach where state variables live at a deterministic storage slot calculated via keccak256. This isolates custom storage from inherited contracts and proxy storage."

**Q. "Tell me about this project"**
"I built an upgradeable fee vault to demonstrate mastery of contract upgrade patterns. The key challenge was designing storage that could evolve from V1 to V2 without collisions. I used Diamond storage - a namespaced pattern where state lives in a deterministic slot calculated via keccak256. This isolated my custom storage from inherited OpenZeppelin contracts. The vault adds security features in V2 like withdrawal delays and limits while preserving all V1 state."

**Q. "Why UUPS over Transparent Proxy?"**
"UUPS is more gas-efficient because upgrade logic lives in the implementation. Each call saves ~2000 gas. The tradeoff is you must be careful with _authorizeUpgrade() - I used onlyOwner to ensure only authorized upgrades. Transparent Proxy is safer but costlier for every transaction."

**Q. "How did you test upgrades?"**
"I wrote 7 tests covering the full upgrade lifecycle. First, I deploy V1 with a proxy, interact to create state, then upgrade to V2 via upgradeToAndCall() with initializeV2(). My tests verify ownership persists, V1 data is intact, and V2 features work. I also test unauthorized upgrade attempts and edge cases like withdrawal delays."


Project Title
Upgradeable Fee Vault - UUPS Proxy with Diamond Storage

description 
Implemented production-grade upgradeable smart contract system using UUPS 
proxy pattern and Diamond storage. Designed V1→V2 migration path preserving 
state while adding security features (withdrawal delays, limits, pause). 
Comprehensive test coverage (7/7 passing) validates upgrade safety and 
feature correctness.


"V2 adds withdrawal limits for transparency and accident prevention. While the owner can modify them, all changes emit events so users/community can monitor and react. In production, you'd add a timelock (48-hour delay) so users can exit before changes take effect, or use multi-sig ownership to distribute trust. For this portfolio project, I focused on demonstrating the UUPS upgrade pattern and storage safety rather than full governance complexity."


what more test that i could add 

testEmergencyWithdraw - V2 has this function but no test
testMultipleTokens - deposit/withdraw different tokens
testBalanceTracking - verify V2 balance accuracy after multiple ops