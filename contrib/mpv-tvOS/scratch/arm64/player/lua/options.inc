// Generated from player/lua/options.lua

"local msg = require 'mp.msg'\n"
"\n"
"local function val2str(val)\n"
"    if type(val) == \"boolean\" then\n"
"        if val then val = \"yes\" else val = \"no\" end\n"
"    end\n"
"    return val\n"
"end\n"
"\n"
"-- converts val to type of desttypeval\n"
"local function typeconv(desttypeval, val)\n"
"    if type(desttypeval) == \"boolean\" then\n"
"        if val == \"yes\" then\n"
"            val = true\n"
"        elseif val == \"no\" then\n"
"            val = false\n"
"        else\n"
"            msg.error(\"Error: Can't convert \" .. val .. \" to boolean!\")\n"
"            val = nil\n"
"        end\n"
"    elseif type(desttypeval) == \"number\" then\n"
"        if not (tonumber(val) == nil) then\n"
"            val = tonumber(val)\n"
"        else\n"
"            msg.error(\"Error: Can't convert \" .. val .. \" to number!\")\n"
"            val = nil\n"
"        end\n"
"    end\n"
"    return val\n"
"end\n"
"\n"
"\n"
"local function read_options(options, identifier)\n"
"    if identifier == nil then\n"
"        identifier = mp.get_script_name()\n"
"    end\n"
"    msg.debug(\"reading options for \" .. identifier)\n"
"\n"
"    -- read config file\n"
"    local conffilename = \"script-opts/\" .. identifier .. \".conf\"\n"
"    local conffile = mp.find_config_file(conffilename)\n"
"    if conffile == nil then\n"
"        msg.verbose(conffilename .. \" not found.\")\n"
"        conffilename = \"lua-settings/\" .. identifier .. \".conf\"\n"
"        conffile = mp.find_config_file(conffilename)\n"
"        if conffile then\n"
"            msg.warn(\"lua-settings/ is deprecated, use directory script-opts/\")\n"
"        end\n"
"    end\n"
"    local f = conffile and io.open(conffile,\"r\")\n"
"    if f == nil then\n"
"        -- config not found\n"
"        msg.verbose(conffilename .. \" not found.\")\n"
"    else\n"
"        -- config exists, read values\n"
"        local linecounter = 1\n"
"        for line in f:lines() do\n"
"            if string.find(line, \"#\") == 1 then\n"
"\n"
"            else\n"
"                local eqpos = string.find(line, \"=\")\n"
"                if eqpos == nil then\n"
"\n"
"                else\n"
"                    local key = string.sub(line, 1, eqpos-1)\n"
"                    local val = string.sub(line, eqpos+1)\n"
"\n"
"                    -- match found values with defaults\n"
"                    if options[key] == nil then\n"
"                        msg.warn(conffilename..\":\"..linecounter..\n"
"                            \" unknown key \" .. key .. \", ignoring\")\n"
"                    else\n"
"                        local convval = typeconv(options[key], val)\n"
"                        if convval == nil then\n"
"                            msg.error(conffilename..\":\"..linecounter..\n"
"                                \" error converting value '\" .. val ..\n"
"                                \"' for key '\" .. key .. \"'\")\n"
"                        else\n"
"                            options[key] = convval\n"
"                        end\n"
"                    end\n"
"                end\n"
"            end\n"
"            linecounter = linecounter + 1\n"
"        end\n"
"        io.close(f)\n"
"    end\n"
"\n"
"    --parse command-line options\n"
"    for key, val in pairs(mp.get_property_native(\"options/script-opts\")) do\n"
"        local prefix = identifier..\"-\"\n"
"        if not (string.find(key, prefix, 1, true) == nil) then\n"
"            key = string.sub(key, string.len(prefix)+1)\n"
"\n"
"            -- match found values with defaults\n"
"            if options[key] == nil then\n"
"                msg.warn(\"script-opts: unknown key \" .. key .. \", ignoring\")\n"
"            else\n"
"                local convval = typeconv(options[key], val)\n"
"                if convval == nil then\n"
"                    msg.error(\"script-opts: error converting value '\" .. val ..\n"
"                        \"' for key '\" .. key .. \"'\")\n"
"                else\n"
"                    options[key] = convval\n"
"                end\n"
"            end\n"
"        end\n"
"    end\n"
"\n"
"end\n"
"\n"
"-- backwards compatibility with broken read_options export\n"
"_G.read_options = read_options\n"
"\n"
"return {\n"
"    read_options = read_options,\n"
"}\n"
