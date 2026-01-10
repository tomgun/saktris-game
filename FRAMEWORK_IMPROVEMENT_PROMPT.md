# Framework Improvement Prompt

Use this prompt to improve the agentic framework to ensure test coverage is verified automatically.

---

## Problem Statement

We discovered that feature F-0014 (BishopPlacementRule) was marked as:
- `Status: shipped`
- `Strategy: unit`
- `Unit: complete`

But it had **zero unit tests**. This gap was only caught during a manual audit.

## Root Cause

The framework lacks automated verification that:
1. Features with `Strategy: unit` actually have corresponding test files/functions
2. Acceptance criteria are mapped to specific tests
3. Shipping a feature validates test coverage

## Desired Behavior

When an agent marks a feature as `shipped` with `Strategy: unit`:
1. **Pre-ship validation**: Verify tests exist before allowing status change to `shipped`
2. **AC-to-test mapping**: Each acceptance criterion should reference its test(s)
3. **Coverage reporting**: Show which ACs have tests and which are untested

---

## Prompt for Framework Enhancement

```
I need to enhance the agentic framework to ensure automated test coverage verification for features. Here's what should happen:

### 1. Add Test Verification to Feature Workflow

When a feature's status changes to `shipped` and its test strategy is `unit`:

1. Parse the acceptance criteria file (spec/acceptance/F-####.md)
2. Search for test files matching the feature (by convention or explicit mapping)
3. Verify at least one test function exists for each testable AC
4. Block the status change if tests are missing, or warn with specific gaps

### 2. Enhance FEATURES.md Schema

Add optional `test_mapping` field to track AC-to-test relationships:

```yaml
- Tests:
  - Strategy: unit
  - Unit: complete
  - Test file: tests/unit/test_board.gd
  - AC mapping:
    - AC1: test_bishop_placement_same_color_blocked
    - AC2: manual (visual)
    - AC3: test_bishop_placement_per_player_independent
```

### 3. Add Pre-Commit Hook for Test Coverage

Create `.agentic/hooks/verify-test-coverage.sh` that:
- Runs on feature status changes
- Parses FEATURES.md for features with `Strategy: unit`
- Verifies test files exist and contain test functions
- Reports coverage gaps before commit

### 4. Add Agent Instruction for Test Verification

In the feature implementation checklist, add:

**Before marking shipped:**
- [ ] If Strategy is `unit`, verify test file exists
- [ ] Count test functions - should match or exceed AC count (minus manual ACs)
- [ ] Run tests and confirm they pass
- [ ] Update FEATURES.md with test file reference

### 5. Create Test Coverage Report Tool

Add `.agentic/tools/test_coverage.sh` that:
- Scans all features with `Strategy: unit`
- Cross-references with test directories
- Reports:
  - Features with tests
  - Features missing tests
  - AC coverage percentage per feature

Example output:
```
Test Coverage Report
====================
F-0003 PieceMovementRules: 8/8 ACs covered (100%)
F-0004 PieceArrivalSystem: 7/7 ACs covered (100%)
F-0014 BishopPlacementRule: 0/3 ACs covered (0%) ← MISSING TESTS

Overall: 94% features with unit strategy have tests
```

### 6. Integration Points

- `before_commit.md` checklist: Add test verification step
- `feature_implementation.md` workflow: Add test-before-ship gate
- Agent operating guidelines: Mandate test verification for unit-strategy features

### Implementation Priority

1. **High**: Pre-commit test existence check (prevents the F-0014 situation)
2. **Medium**: AC-to-test mapping in FEATURES.md schema
3. **Low**: Full coverage report tool (nice for audits)

### Success Criteria

After implementing:
- An agent cannot mark a feature `shipped` with `Strategy: unit` unless tests exist
- The framework warns when AC count doesn't match test function count
- Test file references are tracked in FEATURES.md
- Pre-commit hooks catch missing tests before they're committed
```

---

## Key Files to Modify in Framework

1. `.agentic/checklists/before_commit.md` - Add test verification
2. `.agentic/checklists/feature_implementation.md` - Add test gate before ship
3. `.agentic/spec/FEATURES.reference.md` - Add test_mapping schema
4. `.agentic/hooks/pre-commit-check.sh` - Add test existence validation
5. `.agentic/tools/test_coverage.sh` - New tool for coverage reports
6. `.agentic/agents/shared/agent_operating_guidelines.md` - Add test verification mandate

---

## Example Validation Logic (Pseudocode)

```python
def verify_feature_tests(feature_id: str) -> bool:
    feature = parse_features_md(feature_id)

    if feature.status != "shipped":
        return True  # Not shipping yet, skip

    if feature.test_strategy != "unit":
        return True  # Manual testing, skip

    acceptance = parse_acceptance_file(feature_id)
    testable_acs = [ac for ac in acceptance if not ac.is_manual]

    test_file = find_test_file(feature)
    if not test_file:
        error(f"{feature_id} has Strategy: unit but no test file found")
        return False

    test_functions = extract_test_functions(test_file)

    if len(test_functions) < len(testable_acs):
        warn(f"{feature_id} has {len(testable_acs)} testable ACs but only {len(test_functions)} tests")

    return True
```

---

## Immediate Actions for Current Project

1. Run tests to verify the new F-0014 tests pass
2. Consider adding test file references to all FEATURES.md entries
3. Add a simple pre-commit check that greps for test functions
