--- Library to process data through a pipeline.
-- Callable module.
-- @classmod Pipeflow
local Pipeflow = {}

-- Logger
local logger_map_level_name = {
	debug = 0,
	info = 1,
	warn = 2,
	error = 3,
}

local Logger = {}

function Logger:new(options)
	local instance = {
		level = "info",
		name = options and options.name or "",
	}

	setmetatable(instance, { __index = Logger })

	if options and options.level then
		instance:set_level(options.level)
	end

	local function createLoggerLevel(label)
		return function(text, ...)
			if logger_map_level_name[label] >= logger_map_level_name[instance.level] then
				local arg = { ... }
				print(
					string.format(
						"%s %s[%s]: %s",
						os.date("!%c"),
						instance.name and string.format("{%s} ", instance.name) or "",
						label,
						#arg > 0 and string.format(text, ...) or text
					)
				)
			end
		end
	end

	for _, label in ipairs({ "debug", "info", "warn", "error" }) do
		instance[label] = createLoggerLevel(label)
	end

	return instance
end

function Logger:set_level(level)
	if logger_map_level_name[self.level] == nil then
		error(string.format("Level is not allowed: %s", tostring(level)))
	end
	self.level = level
end

function Logger:get_logger(options)
	local new_options = {
		level = options and options.level ~= nil and options.level or self.level,
	}

	if options and options.name then
		new_options.name = string.format("%s:%s", self.name, options.name)
	end

	return Logger:new(new_options)
end

-- Utils

-- Return a boolean from a value
local function tobool(value)
	if value then
		return true
	else
		return false
	end
end

-- Find a processor
local function find_processor(name, processors)
	return processors[name]
end

-- Combine tables without overwriting
local function combine_tables_no_overwrite(base, ...)
	local tables = { ... }
	if #tables == 0 then
		return base
	end

	local tbl = tables[1]

	if type(tbl) == "table" then
		for k, v in pairs(tbl) do
			if not base[k] then
				base[k] = v
			end
		end
	end
	table.remove(tables, 1)
	return combine_tables_no_overwrite(base, unpack(tables))
end

-- Evaluate code for Lua 5.1
local function evaluate_lua_51(str, ctx)
	-- If no condition is provided, default to true.
	if not str then
		return true
	end

	-- load() interprets the statement.
	local fn, err = loadstring(str)
	if not fn then
		error("Error compiling condition '" .. str .. "': " .. err)
	end

	-- Set the environment for the loaded function so it only sees allowed context
	setfenv(fn, ctx or {})

	return fn() -- Returns the result
end

-- Evaluate code for Lua 5.2 or latest
local function evaluate_lua_52(str, ctx)
	-- If no condition is provided, default to true.
	if not str then
		return true
	end

	-- In Lua 5.2 and later, load accepts an environment as the fourth parameter.
	local fn, err = load(str, "eval", "t", ctx or {})
	if not fn then
		error("Compilation error: " .. err)
	end

	return fn() -- Returns the result
end

local evaluate

if _VERSION == "Lua 5.1" then
	evaluate = evaluate_lua_51
else
	evaluate = evaluate_lua_52
end

-- Evalute return
local function evaluate_return(condition_str, ctx)
	return evaluate("return " .. condition_str, ctx)
end

-- Function to safely evaluate a condition string.
-- It takes the condition's string and a custom environment (env) which defines the allowed variables.
local function evaluate_condition(condition_str, ctx)
	return tobool(evaluate_return(condition_str, ctx))
end

-- Function to iterate over a processor group
-- and decide whether to apply each processor.
local function _run_pipeline(pipeline, processors, data, ctx, pm)
	if pipeline == nil then
		error("No pipeline")
	end

	local skip = false
	local function end_pipeline()
		skip = true
	end

	for i, step in ipairs(pipeline) do
		local logger = pm.logger:get_logger({
			name = string.format("step[type=%s]", step.type) .. (step.tag and string.format("[tag=%s]", step.tag) or ""),
		})
		logger.debug("Running step")
		local processor = find_processor(step["type"], processors) or step.processor

		if processor then
			local should_run = true
			if step["if"] then
				-- Evaluate the "if" condition.
				logger.debug(string.format("Evaluating condition [%s]", tostring(step["if"])))
				local if_eval = combine_tables_no_overwrite({}, { data = data }, { ctx = ctx })
				should_run = evaluate_condition(step["if"], if_eval)
				logger.debug(string.format("Evaluated condition [%s]: %s", tostring(step["if"]), tostring(should_run)))
			end

			if should_run then
				logger.debug("Applying processor")
				local ok, err = pcall(function()
					return processor(step.options, data, ctx, {
						end_pipeline = end_pipeline,
						evaluate_condition = evaluate_condition,
						evaluate_return = evaluate_return,
						evaluate = evaluate,
						find_processor = find_processor,
						logger = logger
					})
				end)
				if skip then
					logger.debug("Stopping pipeline")
					break
				end

				-- Manage error
				if not ok then
					if step.on_failure then
						data = _run_pipeline(step.on_failure, processors, data, ctx, {logger=logger})
						if skip then
							logger.debug("Stopping pipeline")
							break
						end
					else
						if step.ignore_failure then
							logger.debug(string.format("Failure was ignored", err))
						else
							logger.error(string.format("An error happened %s", err))
							error(err)
							break
						end
					end
				else
					data = err
				end
			else
				logger.debug("Processor does not run")
			end
		else
			logger.warn("Skipping processor due to not found")
		end
	end
	return data
end

--- Call the module to run a pipeline.
-- @function __call
-- @tparam table pipeline Pipeline definition
-- @tparam table processors Processors
-- @tparam any data Initial value of data variable.
-- @tparam table ctx Context (ctx) variable.
-- @tparam table utils variable. Context.
-- @tparam function utils.logger Logger.
-- @tparam function utils.create_logger Create logger function.
-- @return Result of run_pipeline
local function run_pipeline(pipeline, processors, data, ctx, utils)
	local logger = utils and utils.logger or (utils and utils.create_logger and utils.create_logger(pipeline))

	if not logger then
		logger = Logger:new({ name = pipeline.name })
	else
		logger = logger:get_logger({ name = pipeline.name })
	end
	logger.debug("Running pipeline")
	return _run_pipeline(pipeline.processors, processors, data, ctx, { logger = logger })
end

Pipeflow.__index = Pipeflow
Pipeflow.__call = function(t, ...)
	return run_pipeline(...)
end

--- Create a processor manager instance
-- @usage
-- local pipeflow = require("pipeflow")
-- local mypipeflow = pipeflow:new({name = "mypipeline", logger_level = "info"})
-- @tparam options options
-- @string[opt=""] options.name Name.
-- @tparam[opt="info"] string options.logger_level Logger level, one of "debug", "info", "warn", "error"
-- @treturn Pipeflow
function Pipeflow:new(options)
	local instance = setmetatable({}, Pipeflow)
	instance.name = options and options.name
	instance.logger = Logger:new({ name = instance.name, level = options and options.logger_level })
	instance.processors = {}
	return instance
end

--- Register a processor.
-- @usage 
--	mypipeflow:register("myprocessor",
--    function add(step_options, data, ctx, utils)
--      return data + step_options.value
--    end
--  )
-- @param name string Processor name
-- @tparam pipeflow_processor.run processor Processor run function
-- @treturn Pipeflow
function Pipeflow:register(name, processor)
	if type(name) == "table" and processor == nil then
		for k, v in pairs(name) do
			self:register(k, v)
		end
	else
		self.logger.debug("Registering processor [%s]", name)
		if self.processors[name] ~= nil then
			error(string.format("Processor [%s] already exists", name))
		end
		self.processors[name] = processor
		self.logger.debug("Registered processor [%s]", name)
	end

	return self
end

--- Run pipeline.
-- @usage 
--	mypipeflow:run_pipeline(mypipeline, initial_data, ctx, my_unregistered_processors)
-- @tparam table pipeline Pipeline definition.
-- @tparam any data Initial value of data variable.
-- @tparam table ctx Context (ctx) variable.
-- @tparam table unregistered_processors Unregistred processors.
-- @return any
function Pipeflow:run_pipeline(pipeline, data, ctx, unregistered_processors)
	self.logger.debug("Running pipeline")
	local processors = self.processors
	if unregistered_processors then
		self.logger.debug("Adding unregistered processors to processors")
		processors = combine_tables_no_overwrite({}, self.processors, unregistered_processors)
		self.logger.debug("Adding unregistered processors to processors")
	end

	return run_pipeline(pipeline, processors, data, ctx or {}, { logger = self.logger })
end

--- Evaluate code.
-- @usage 
--	mypipeflow:evaluate("3+result", {result = 4})
-- @tparam string str Code to eval.
-- @tparam table ctx ctx variable. Context.
-- @return any
function Pipeflow:evaluate(str, ctx)
	return evaluate(str, ctx)
end

--- Evaluate return code.
-- @usage 
--	mypipeflow:evaluate_return("3+result", {result = 4})
-- @tparam string str Code to eval.
-- @tparam table ctx ctx variable. Context.
-- @return any
function Pipeflow:evaluate_return(str, ctx)
	return evaluate_return(str, ctx)
end

--- Evaluate condition code.
-- @usage 
--	mypipeflow:evaluate_condition("3+2 > result", {result = 4})
-- @tparam string str Code to eval.
-- @tparam table ctx ctx variable. Context.
-- @return boolean
function Pipeflow:evaluate_condition(str, ctx)
	return evaluate_condition(str, ctx)
end

return setmetatable({}, Pipeflow)

--- Does the processor run function.
-- @function pipeflow_processor.run
-- @tparam table step_options Step options
-- @tparam any data data variable.
-- @tparam table ctx Context (ctx) variable
-- @tparam table utils Utils variable
-- @tparam function utils.end_pipeline Mark the pipeline to skip
-- @tparam Pipeflow.evaluate_condition utils.evaluate_condition Mark the pipeline to skip
-- @tparam Pipeflow.evaluate_return utils.evaluate_return Mark the pipeline to skip
-- @tparam Pipeflow.evaluate utils.evaluate Mark the pipeline to skip
-- @tparam Pipeflow.evaluate utils.evaluate Mark the pipeline to skip
-- @tparam function utils.find_processor Find the processor in the pipeline
-- @tparam table utils.logger Step logger instance
-- @treturn table utils
