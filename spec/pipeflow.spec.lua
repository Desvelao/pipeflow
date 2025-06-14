local PM = require("pipeflow")

local function processor_sum(options, data)
	return data + options.value
end

local function processor_multiply(options, data)
	return data * options.value
end

local function processor_difference(options, data)
	return data - options.value
end

local function processor_text_upper(options, data)
	return data:upper()
end

local function processor_text_concat(options, data)
	return data .. options.value
end

local function processor_text_lower(options, data)
	return data:lower()
end

local function processor_text_set(options, data)
	return options.value
end

local function processor_error_message(options, data)
	error(options.message)
end

local function processor_skip(options, data, env, utils)
	utils.end_pipeline()
end

describe("Run pipeline", function()
	local processors = {
		sum = processor_sum,
		multiply = processor_multiply,
		difference = processor_difference,
		error = processor_error_message,
		upper = processor_text_upper,
		concat = processor_text_concat,
		lower = processor_text_lower,
		set = processor_text_set,
		skip = processor_skip,
	}

	it("Basic pipeline", function()
		local pipeline = {
			name = "pipeline1",
			processors = {
				{
					type = "sum",
					options = {
						value = 2,
					},
				},
				{
					type = "multiply",
					options = {
						value = 3,
					},
				},
				{
					type = "difference",
					options = {
						value = 1,
					},
				},
				{
					type = "multiply",
					options = {
						value = 5,
					},
				},
			},
		}
		assert.are.equal(25, PM(pipeline, processors, 0, {}))
		assert.are.equal(40, PM(pipeline, processors, 1, {}))
		assert.are.equal(1075, PM(pipeline, processors, 70, {}))
		assert.are.equal(4525, PM(pipeline, processors, 300, {}))
		assert.are.equal(-50, PM(pipeline, processors, -5, {}))
		assert.are.equal(-5, PM(pipeline, processors, -2, {}))
	end)

	it("Basic pipeline with conditional processor", function()
		local pipeline = {
			name = "pipeline1",
			processors = {
				{
					type = "upper",
				},
				{
					type = "concat",
					options = {
						value = "aBcDe",
					},
				},
				{
					type = "concat",
					options = {
						value = "zYx",
					},
				},
				{
					["if"] = "data:sub(1, 1) == 'A'",
					type = "upper",
				},
			},
		}

		assert.are.equal("AABCDEZYX", PM(pipeline, processors, "A"))
		assert.are.equal("AABCDEZYX", PM(pipeline, processors, "a"))
		assert.are.equal("ABABCDEZYX", PM(pipeline, processors, "ab"))
		assert.are.equal("BaBcDezYx", PM(pipeline, processors, "b"))
	end)

	it("Run pipeline with conditional processors and error", function()
		local pipeline = {
			name = "pipeline1",
			processors = {
				{
					type = "upper",
				},
				{
					type = "concat",
					options = {
						value = "aBcDe",
					},
				},
				{
					["if"] = "data:sub(1, 1) == 'A'",
					type = "error",
					options = {
						message = "This is a expected error!!",
					},
				},
				{
					type = "concat",
					options = {
						value = "zYx",
					},
				},
				{
					["if"] = "data:sub(1, #'A') == 'A'",
					type = "upper",
				},
			},
		}

		-- print(pm:run_pipeline(pipeline, 'A'))
		assert.has.errors(function()
			PM(pipeline, processors, "A")
		end)
		assert.has_no.errors(function()
			PM(pipeline, processors, "B")
		end)
		assert.has_no.errors(function()
			PM(pipeline, processors, "C")
		end)
	end)

	it("Pipeline with conditional processor on failure", function()
		local pipeline = {
			name = "pipeline1",
			processors = {
				{
					type = "upper",
				},
				{
					type = "concat",
					options = {
						value = "aBcDe",
					},
				},
				{
					["if"] = "data:sub(1, 1) == 'A'",
					type = "error",
					options = {
						message = "This is a expected error!!",
					},
					on_failure = {
						{
							type = "set",
							options = {
								value = "-ERROR_RECOVERED-",
							},
						},
					},
				},
				{
					type = "concat",
					options = {
						value = "zYx",
					},
				},
				{
					["if"] = "data:sub(1, #'A') == 'A'",
					type = "upper",
				},
			},
		}

		assert.are.equal("-ERROR_RECOVERED-zYx", PM(pipeline, processors, "A"))
	end)

	it("Pipeline with conditional processor error", function()
		local pipeline = {
			name = "pipeline1",
			processors = {
				{
					type = "upper",
				},
				{
					type = "concat",
					options = {
						value = "aBcDe",
					},
				},
				{
					["if"] = "data:sub(1, 1) == 'A'",
					type = "error",
					options = {
						message = "This is a expected error!!",
					},
				},
				{
					type = "concat",
					options = {
						value = "zYx",
					},
				},
				{
					["if"] = "data:sub(1, #'A') == 'A'",
					type = "upper",
				},
			},
		}

		assert.has.errors(function()
			PM(pipeline, processors, "A")
		end)
	end)

	it("Run pipeline on failure recovered", function()
		local pipeline = {
			name = "pipeline1",
			processors = {
				{
					type = "upper",
				},
				{
					type = "concat",
					options = {
						value = "aBcDe",
					},
				},
				{
					["if"] = "data:sub(1, 1) == 'A'",
					type = "error",
					ignore_failure = true,
					options = {
						message = "This is a expected error!!",
					},
				},
				{
					type = "concat",
					options = {
						value = "zYx",
					},
				},
				{
					["if"] = "data:sub(1, #'A') == 'A'",
					type = "upper",
				},
			},
		}

		assert.are.equal("AABCDEZYX", PM(pipeline, processors, "A"))
	end)

	it("Run pipeline skip", function()
		local pipeline = {
			name = "pipeline1",
			processors = {
				{
					type = "upper",
				},
				{
					type = "concat",
					options = {
						value = "aBcDe",
					},
				},
				{
					type = "skip",
				},
				{
					["if"] = "data:sub(1, 1) == 'A'",
					type = "error",
					ignore_failure = true,
					options = {
						message = "This is a expected error!!",
					},
				},
				{
					type = "concat",
					options = {
						value = "zYx",
					},
				},
				{
					["if"] = "data:sub(1, #'A') == 'A'",
					type = "upper",
				},
			},
		}

		assert.are.equal("AaBcDe", PM(pipeline, processors, "A"))
	end)
end)

describe("Processor manager", function()
	describe("Create a processor manager", function()
		it("Create processor manager with name", function()
			local pm = PM:new({ name = "Test" })

			assert.are.equals("Test", pm.name)
		end)

		it("Create processor manager with no name", function()
			local pm = PM:new()

			assert.are.equals(nil, pm.name)
		end)
	end)

	describe("Register processors", function()
		local pm
		before_each(function()
			pm = PM:new({ name = "Test" })
		end)

		it("Register processor", function()
			pm:register("processor_test", function() end)

			assert.is.truthy(pm.processors["processor_test"])
		end)

		it("Register processor", function()
			pm:register("processor_test2", function() end)
			assert.is.truthy(pm.processors["processor_test2"])

			pm:register("processor_test3", function() end)
			assert.is.truthy(pm.processors["processor_test3"])

			assert.is_not.truthy(pm.processors["processor_test"])
		end)
	end)

	describe("Evaluate", function()
		local pm
		before_each(function()
			pm = PM:new({ name = "Test" })
		end)

		it("Evaluate 2+4", function()
			assert.are.equal(6, pm:evaluate("return 2+4"))
		end)

		it("Evaluate true and false", function()
			assert.are.equal(false, pm:evaluate("return true and false"))
		end)

		it("Evaluate with context", function()
			assert.are.equal(6, pm:evaluate("return a+b", { a = 2, b = 4 }))
		end)
	end)

	describe("Evaluate condition", function()
		local pm
		before_each(function()
			pm = PM:new({ name = "Test" })
		end)

		it("Evaluate 2+4", function()
			assert.are.equal(true, pm:evaluate_condition("2+4 > 5"))
		end)

		it("Evaluate true and false", function()
			assert.are.equal(false, pm:evaluate_condition("true and false"))
		end)

		it("Evaluate with context", function()
			assert.are.equal(true, pm:evaluate_condition("a+b > c", { a = 2, b = 4, c = 5 }))
		end)

		it("Evaluate with context", function()
			assert.are.equal(false, pm:evaluate_condition("a+b > c", { a = 2, b = 4, c = 6 }))
		end)
	end)

	describe("Run pipeline", function()
		it("Basic pipeline", function()
			local pm = PM:new({ name = "Test" })
			pm:register("sum", processor_sum)
			pm:register("multiply", processor_multiply)
			pm:register("difference", processor_difference)

			local pipeline = {
				name = "pipeline1",
				processors = {
					{
						type = "sum",
						options = {
							value = 2,
						},
					},
					{
						type = "multiply",
						options = {
							value = 3,
						},
					},
					{
						type = "difference",
						options = {
							value = 1,
						},
					},
					{
						type = "multiply",
						options = {
							value = 5,
						},
					},
				},
			}

			assert.are.equal(25, pm:run_pipeline(pipeline, 0))
			assert.are.equal(40, pm:run_pipeline(pipeline, 1))
			assert.are.equal(1075, pm:run_pipeline(pipeline, 70))
			assert.are.equal(4525, pm:run_pipeline(pipeline, 300))
			assert.are.equal(-50, pm:run_pipeline(pipeline, -5))
			assert.are.equal(-5, pm:run_pipeline(pipeline, -2))
		end)

		it("Basic pipeline with conditional processor", function()
			local pm = PM:new({ name = "Test" })
			pm:register("upper", processor_text_upper)
			pm:register("concat", processor_text_concat)
			pm:register("lower", processor_text_lower)

			local pipeline = {
				name = "pipeline1",
				processors = {
					{
						type = "upper",
					},
					{
						type = "concat",
						options = {
							value = "aBcDe",
						},
					},
					{
						type = "concat",
						options = {
							value = "zYx",
						},
					},
					{
						["if"] = "data:sub(1, 1) == 'A'",
						type = "upper",
					},
				},
			}

			assert.are.equal("AABCDEZYX", pm:run_pipeline(pipeline, "A"))
			assert.are.equal("AABCDEZYX", pm:run_pipeline(pipeline, "a"))
			assert.are.equal("ABABCDEZYX", pm:run_pipeline(pipeline, "ab"))
			assert.are.equal("BaBcDezYx", pm:run_pipeline(pipeline, "b"))
		end)

		it("Run pipeline with conditional processors and error", function()
			local pm = PM:new({ name = "Test" })
			pm:register("upper", processor_text_upper)
			pm:register("concat", processor_text_concat)
			pm:register("lower", processor_text_lower)
			pm:register("error", processor_error_message)

			local pipeline = {
				name = "pipeline1",
				processors = {
					{
						type = "upper",
					},
					{
						type = "concat",
						options = {
							value = "aBcDe",
						},
					},
					{
						["if"] = "data:sub(1, 1) == 'A'",
						type = "error",
						options = {
							message = "This is a expected error!!",
						},
					},
					{
						type = "concat",
						options = {
							value = "zYx",
						},
					},
					{
						["if"] = "data:sub(1, #'A') == 'A'",
						type = "upper",
					},
				},
			}

			-- print(pm:run_pipeline(pipeline, 'A'))
			assert.has.errors(function()
				pm:run_pipeline(pipeline, "A")
			end)
			assert.has_no.errors(function()
				pm:run_pipeline(pipeline, "B")
			end)
			assert.has_no.errors(function()
				pm:run_pipeline(pipeline, "C")
			end)
		end)

		it("Pipeline with conditional processor on failure", function()
			local pm = PM:new({ name = "Test" })
			pm:register("upper", processor_text_upper)
			pm:register("concat", processor_text_concat)
			pm:register("lower", processor_text_lower)
			pm:register("error", processor_error_message)
			pm:register("set", processor_text_set)

			local pipeline = {
				name = "pipeline1",
				processors = {
					{
						type = "upper",
					},
					{
						type = "concat",
						options = {
							value = "aBcDe",
						},
					},
					{
						["if"] = "data:sub(1, 1) == 'A'",
						type = "error",
						options = {
							message = "This is a expected error!!",
						},
						on_failure = {
							{
								type = "set",
								options = {
									value = "-ERROR_RECOVERED-",
								},
							},
						},
					},
					{
						type = "concat",
						options = {
							value = "zYx",
						},
					},
					{
						["if"] = "data:sub(1, #'A') == 'A'",
						type = "upper",
					},
				},
			}

			assert.are.equal("-ERROR_RECOVERED-zYx", pm:run_pipeline(pipeline, "A"))
		end)

		it("Pipeline with conditional processor error", function()
			local pm = PM:new({ name = "Test" })
			pm:register("upper", processor_text_upper)
			pm:register("concat", processor_text_concat)
			pm:register("lower", processor_text_lower)
			pm:register("error", processor_error_message)
			pm:register("set", processor_text_set)

			local pipeline = {
				name = "pipeline1",
				processors = {
					{
						type = "upper",
					},
					{
						type = "concat",
						options = {
							value = "aBcDe",
						},
					},
					{
						["if"] = "data:sub(1, 1) == 'A'",
						type = "error",
						options = {
							message = "This is a expected error!!",
						},
					},
					{
						type = "concat",
						options = {
							value = "zYx",
						},
					},
					{
						["if"] = "data:sub(1, #'A') == 'A'",
						type = "upper",
					},
				},
			}

			assert.has.errors(function()
				pm:run_pipeline(pipeline, "A")
			end)
		end)

		it("Run pipeline on failure recovered", function()
			local pm = PM:new({ name = "Test" })
			pm:register("upper", processor_text_upper)
			pm:register("concat", processor_text_concat)
			pm:register("lower", processor_text_lower)
			pm:register("error", processor_error_message)
			pm:register("set", processor_text_set)

			local pipeline = {
				name = "pipeline1",
				processors = {
					{
						type = "upper",
					},
					{
						type = "concat",
						options = {
							value = "aBcDe",
						},
					},
					{
						["if"] = "data:sub(1, 1) == 'A'",
						type = "error",
						ignore_failure = true,
						options = {
							message = "This is a expected error!!",
						},
					},
					{
						type = "concat",
						options = {
							value = "zYx",
						},
					},
					{
						["if"] = "data:sub(1, #'A') == 'A'",
						type = "upper",
					},
				},
			}

			assert.are.equal("AABCDEZYX", pm:run_pipeline(pipeline, "A"))
		end)

		it("Run pipeline skip", function()
			local pm = PM:new({ name = "Test" })
			pm:register("upper", processor_text_upper)
			pm:register("concat", processor_text_concat)
			pm:register("lower", processor_text_lower)
			pm:register("error", processor_error_message)
			pm:register("set", processor_text_set)
			pm:register("skip", processor_skip)

			local pipeline = {
				name = "pipeline1",
				processors = {
					{
						type = "upper",
					},
					{
						type = "concat",
						options = {
							value = "aBcDe",
						},
					},
					{
						type = "skip",
					},
					{
						["if"] = "data:sub(1, 1) == 'A'",
						type = "error",
						ignore_failure = true,
						options = {
							message = "This is a expected error!!",
						},
					},
					{
						type = "concat",
						options = {
							value = "zYx",
						},
					},
					{
						["if"] = "data:sub(1, #'A') == 'A'",
						type = "upper",
					},
				},
			}

			assert.are.equal("AaBcDe", pm:run_pipeline(pipeline, "A"))
		end)
	end)
end)
