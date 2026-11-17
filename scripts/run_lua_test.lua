-- Fengari's interactive error handler can print a Lua error and exit zero.
-- Explicitly propagate failures to Python/CI.
local ok, message = xpcall(function() dofile(arg[1]); end, debug.traceback);
if not ok then io.stderr:write(tostring(message) .. "\n"); os.exit(1); end
