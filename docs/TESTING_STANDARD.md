# DPN Technology FiveM Testing Standard

DPN resources should be tested beyond the "happy path."

## Minimum Test Matrix

### Startup
- Fresh server start
- Resource restart
- Dependency restart where applicable

### Player Lifecycle
- First connect
- Character load
- Character unload
- Reconnect
- Job change
- Duty change where applicable

### Configuration
- Default configuration
- Disabled optional features
- Invalid configuration handling

### Permissions
- Authorized user
- Unauthorized user
- Wrong job
- Wrong grade
- Missing ACE permission

### Error Conditions
- Missing dependency
- Database unavailable
- Invalid callback input
- Missing entity
- Stale entity
- Invalid identifier

### Security
- Repeated event calls
- Invalid values
- Excessively large values
- Negative values
- Remote event call without proper state
- NUI request with manipulated values

### Performance
- Idle player
- Player near interaction
- Multiple players
- Repeated use
- Long session

## Test Report

For major resources, record:

- FiveM artifact
- Framework version
- Dependency versions
- Number of test players
- Known limitations
- Passed/failed scenarios

---

**DPN Technology Engineering Standard**  
Created under the direction of Diesel, CEO of DPN Technology
