Kill all processes listening on ports 3000 and 8000.

Use `lsof -ti :3000` and `lsof -ti :8000` to find PIDs, then kill them. Run both port checks in parallel. Report which processes were killed (PID and command name) or confirm that no processes were found on each port.
