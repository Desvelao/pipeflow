# pipeflow

## Description

This library provides a sequentional processor to transform data. This is inspired by the ingest pipeline of Elasticsearch.

It can be used to process any data type and apply changes with different processors.

Each processor can modify the data or use it to print or send to external services.

## Features

- Transform the data using processors
- Run conditional processors defining a condition in Lua language using the data and context (`ctx`)
- Manage errors in the processors using a on failure pipeline
- Skip applygin processors

# Usage

```lua
-- import the library
local pipeflow = require("pipeflow")

-- Define processors
local function sum(options, data, ctx, utils)
    return data + options.value
end

local function multiply(options, data, ctx, utils)
    return data * options.value
end

local function debug(options, data, ctx, utils)
    print(options.label, data)
    return data -- ensure to return the value despite this is not modified
end

local function throw_error(options, data, ctx, utils)
    error(options.message)
    return data
end

-- Define pipeline
local pipeline = {
    description = "Apply operations to a number",
    processors = {
        {
            type = "sum", -- Define the processor type
            options = { -- Define the processor options
                "value" = 2
            }
        },
        {
            ['if']: "data < 2", -- Add a conditional processor using lua language. data is the value to process
            type = "multiply",
            options = {
                "value" = 3
            }
        },
        {
            type = "debug",
            tag = "debbuger-processor", -- define a tag, this is for debugging purpose
            options = {
                "label": "Debug"
            }
        },
        {
            type = "error",
            tag = "error-processor-ignore-failure", -- define a tag, this is for debugging purpose
            options = {
                "message": "This is an error"
            },
            ignore_failure: true -- ignore the errors
        },
        {
            type = "error",
            options = {
                "message": "This is an error"
            }
            on_failure: { -- define a on failure sub pipeline to run if the parent processor fails
                {
                    "type" = "debug",
                    "options" = {
                        "label": "Debug on error"
                    }
                },
            }
        },
        {
            options = {
                "message": "This is a processor defined in the pipeline"
            },
            processor = function(options, data)
                print(options.message)
                return data            
            end
        }
    }
}

local function unregistered_processor(option, data)
    print('This is an unregistered_processor')
    return data
end

local result = pipeflow(
    pipeline, -- pipeline definition
    { sum = sum, multiply = multiply, debug = debug, throw_error = throw_error }, -- define the processors known by the pipeline
    45 -- initial value of the data variable
    {} -- ctx variable
    { logger } -- utils. optional. See pipeline logger
)


-- If you want to use programming based on objects, you can create a new instance
local pipeflow_instance = pipeflow:new({
    name = "my_pipeflow", -- define the name instance used in the logger. optional.
    logger_level="info" -- possible values: debug, info, warn, error. optional.
})

-- Register the processors
pipeflow_instance:register('sum', sum) -- register a processor
pipeflow_instance:register('debug', debug)
                :register('throw_error', throw_error) -- :register retuns the instance
pipeflow_instance:register({multiply=multiply}) -- register processors using table like hash-map

-- Define a processor that will not registered
local function unregistered_processor(option, data)
    print('This is an unregistered_processor')
    return data
end

-- Run the pipeline
pipeflow_instance:run_pipeline(
    pipeline, -- pipeline definition
    45 -- initial value of the data variable
    {} -- ctx variable
    {unregistered_processor = unregistered_processor} -- define unregistered processors. 
)
```

## Pipeline spec

- `name`: define the pipeline name
- `description`: define the pipeline description
- `processors`: define the processor pipeline to run
   - `if` (string): define a condition in Lua language, it has access to `data` variable and optionally to a `ctx` (context) variable
   - `ignore_failure` (boolean): ignore the failure of the processor
   - `tag` (string): define a label for debugging purpose
   - `type` (string): define the type of processor
   - `options` (any): define the options to pass to the processor
   - `on_failure` (table): define a sub pipeline to run if the main processor fails

### Run conditionally a proccessor

```lua 
{
    ['if']: "data < 2", -- Add a conditional processor using lua language. data is the value to process
    type = "multiply",
    options = {
        "value" = 3
    }
},
```

This processor will run if this fulfill the condition in the `if` field.

### Ignore failure

Define the `ignore_failure` field to declare if ignoring the errors in the processor.

```lua 
{
    type = "processor_throw_error",
    ignore_failure = true
},
```

### On failure

Add the `on_failure` field that defines a sub pipeline that will be run if the main processor fails.

```lua
{
    type = "error",
    options = {
        "message": "This is an error"
    }
    on_failure: { -- define a on failure sub pipeline to run if the parent processor fails
        {
            "type" = "debug",
            "options" = {
                "label": "Debug on error"
            }
        },
    }
},
```

## data variable

The `data` variable is the value to transform/manage in the processors.

## ctx variable

The `ctx` variable defines the context for the pipeline run, this can be used in the evaluations of logic of processors.

## Unregistered processors

When using the pipeflow manager, you can pass unregistered processors to the pipeline run.

```lua
-- Run the pipeline
pipeflow_instance:run_pipeline(
    pipeline, -- pipeline definition
    45 -- initial value of the data variable
    {} -- ctx variable
    {unregistered_processor = unregistered_processor} -- define unregistered processors. 
)
```

## Logger

The run pipeline and pipeflow manager can use a logger that has the following methods:

- debug, info, warn, error: define the level log methods
- get_logger: create a child logger used in the pipeline run

# Generate docs

```console
luaroks install ldoc
ldoc .
```

## Change version

Change the version variable in `config.ld`.

# Development

## Run environment

```console
docker compose -f docker-compose.dev.yml up -d
```

## Access to container

```console
docker compose -f docker-compose.dev.yml exec pipeflow-dev sh
```

## Code formatting

- stylua:

> In alpine, it installs the interpeter with:
```
apk add libc6-compat
```
