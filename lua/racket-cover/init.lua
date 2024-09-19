
local util = nil

local M = {}

local coverage_dir = nil

local script_dir = nil

local uncovered = nil
local show_uncovered = false

local uncovered_hl_space = nil
local racket_cover_aug = nil

local do_highlight_uncovered = nil
local do_diagnostic_uncovered = nil

local function construct_uncovered(json_str)
    local uncov = {}
    local uncovered_parts = vim.json.decode(json_str)
    local file_to_key_file = {}
    for _, part in ipairs(uncovered_parts) do
        if not uncov[part.filepath] then
            uncov[part.filepath] = {}
        end
        if not file_to_key_file[part.filepath] then
            file_to_key_file[part.filepath] = coverage_dir .. "/" .. string.gsub(part.filepath, "/", "%%")
        end
        local line = util.byte2line(file_to_key_file[part.filepath], part.offset)
        local col = part.offset - util.line2byte(file_to_key_file[part.filepath], line) + 1
        table.insert(uncov[part.filepath], {line=line, col=col, length=part.length, offset=part.offset})
    end

    for _, file_uncov in pairs(uncov) do
        table.sort(file_uncov, function(a, b)
            return a.line < b.line
        end)
    end

    return uncov
end

local function clear_uncovered_hl(bufnr)
    vim.api.nvim_buf_clear_namespace(bufnr, uncovered_hl_space, 0, -1)
end

local function clear_uncovered_hl_all()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.fn.buflisted(bufnr) == 1 then
            clear_uncovered_hl(bufnr)
        end
    end
end

local function proceeding_indented_identical(lines, comparison, ind1, ind2)
    local ran = false
    while string.match(lines[ind1], "^%s+") ~= nil do
        ran = true

        ind1 = ind1 - 1
        ind2 = ind2 - 1

        if ind1 == 0 or ind2 == 0 then
            return true
        end

        if lines[ind1] ~= comparison[ind2] then
            return false
        end
    end

    if not ran and lines[ind1] ~= comparison[ind2] then
        return false
    end

    return true
end

local function highlight_uncovered(bufnr)
    local buf_path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":p")

    if uncovered == nil then
        uncovered = construct_uncovered(util.read_from_file(coverage_dir .. "/uncovered.json"))
    end

    if not uncovered[buf_path] then
        return
    end

    local parallel_filepath = coverage_dir .. "/" .. string.gsub(buf_path, "/", "%%")

    if vim.loop.fs_stat(parallel_filepath) == nil then
        return
    end

    local file_uncov = uncovered[buf_path]
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
    local parallel_lines = vim.fn.split(util.read_from_file(parallel_filepath), "\n")

    local last_match_line = 1
    local buf_diagnostics = {}
    for _, uncov_part in ipairs(file_uncov) do
        local uncov_line = parallel_lines[uncov_part.line]
        local cur_line = last_match_line
        while cur_line <= #lines do
            if lines[cur_line] == uncov_line and proceeding_indented_identical(parallel_lines, lines, uncov_part.line, cur_line) then
                local api_line = cur_line - 1
                local api_col = uncov_part.col - 1
                local api_col_end = uncov_part.col + uncov_part.length

                if do_diagnostic_uncovered then
                    table.insert(buf_diagnostics, {
                        bufnr = bufnr,
                        lnum = api_line,
                        end_lnum = api_line,
                        col = api_col,
                        end_col = api_col_end,
                        severity = vim.diagnostic.severity.WARN,
                        message = "not covered by tests",
                        source = "Racket Code Coverage",
                        code = uncov_line:sub(uncov_part.col, uncov_part.col + uncov_part.length),
                        namespace = uncovered_hl_space,
                    })
                end

                if do_highlight_uncovered then
                    vim.api.nvim_buf_add_highlight(bufnr, uncovered_hl_space, "racketUncovered", api_line, api_col, api_col_end)
                end

                last_match_line = cur_line
                break
            end
            cur_line = cur_line + 1
        end
    end

    if do_diagnostic_uncovered then
        vim.diagnostic.set(uncovered_hl_space, bufnr, buf_diagnostics)
    end
end

local function highlight_uncovered_all()
    if vim.loop.fs_stat(coverage_dir) == nil then
        return
    end

    clear_uncovered_hl_all()

    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        highlight_uncovered(bufnr)
    end
end

local function set_show_uncovered(val)
    show_uncovered = val

    if show_uncovered then
        highlight_uncovered_all()

        vim.api.nvim_clear_autocmds({ group = racket_cover_aug })

        vim.api.nvim_create_autocmd("BufReadPost", {
            pattern = "*",
            group = racket_cover_aug,
            callback = function (event)
                os.execute("touch ~/temp/bufreadpost.txt")
                if not (vim.api.nvim_buf_get_option(event.buf, "filetype") == "racket" or vim.fn.fnamemodify(event.file, ":e") == "rhm") then
                    os.execute("touch ~/temp/notracket.txt")
                    return
                end
                    os.execute("touch ~/temp/isracket.txt")

                if show_uncovered then
                    os.execute("touch ~/temp/isracketandshowuncovered.txt")
                    clear_uncovered_hl(event.buf)
                    highlight_uncovered(event.buf)
                end
            end
        })

        vim.api.nvim_create_autocmd("TextChanged", {
            pattern = "*",
            group = racket_cover_aug,
            callback = function (event)
                if vim.api.nvim_buf_get_option(event.buf, "filetype") ~= "racket" then
                    return
                end

                if show_uncovered then
                    clear_uncovered_hl(event.buf)
                    highlight_uncovered(event.buf)
                end
            end
        })

        vim.api.nvim_create_autocmd("TextChangedI", {
            pattern = "*",
            group = racket_cover_aug,
            callback = function (event)
                if vim.api.nvim_buf_get_option(event.buf, "filetype") ~= "racket" then
                    return
                end

                if show_uncovered then
                    clear_uncovered_hl(event.buf)
                    highlight_uncovered(event.buf)
                end
            end
        })
    else
        clear_uncovered_hl_all()
        vim.api.nvim_clear_autocmds({ group = racket_cover_aug })
    end
end

local function rktl_to_json_str(rktl_file)
    if script_dir == nil then
        script_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:p")
    end

    local conversion_command = "racket " .. script_dir .. "/racket-cover-convert-rktl.rkt " .. rktl_file
    local handle = io.popen(conversion_command)

    if not handle then
        error("Failed to execute rktl to json command: " .. conversion_command)
    end

    local output = handle:read("*a")
    handle:close()

    return output
end

local function create_user_commands()
    vim.api.nvim_create_user_command(
        'RacketCoverShow', function ()
            set_show_uncovered(true)
        end, { nargs = 0 }
    )

    vim.api.nvim_create_user_command(
        'RacketCoverHide', function ()
            set_show_uncovered(false)
        end, { nargs = 0 }
    )

    vim.api.nvim_create_user_command(
        'RacketCoverToggle', function ()
            set_show_uncovered(not show_uncovered)
            print("Racket Coverage " .. (show_uncovered and "On" or "Off"))
        end, { nargs = 0 }
    )

    vim.api.nvim_create_user_command(
        'RacketCover',
        function(opts)
            local test_file_partials = vim.fn.split(opts.args, ' ')
            local test_files = {}
            for i, filepath in ipairs(test_file_partials) do
                if string.match(test_file_partials[i], "^%%[:phtre]*$") ~= nil then
                    test_files[i] = vim.fn.fnamemodify(vim.fn.expand(filepath), ":p")
                else
                    test_files[i] = vim.fn.fnamemodify(filepath, ":p")
                end
                assert(vim.loop.fs_stat(test_files[i]) ~= nil, "provided filepath does not exist: " .. filepath)
            end

            print("Running coverage...")

            os.execute("rm -rf '" .. coverage_dir .. "'; mkdir -p '" .. coverage_dir .. "'")

            for _, test_file in ipairs(test_files) do
                util.write_to_file(coverage_dir .. "/cp.log", "copying: " .. test_file .. "\ncommand: " .. "cp " .. test_file .. " '" .. coverage_dir .. "/" .. string.gsub(test_file, "/", "%%") .. "'\n")
                os.execute("cp " .. test_file .. " '" .. coverage_dir .. "/" .. string.gsub(test_file, "/", "%%") .. "' &>>'" .. coverage_dir .. "/cp.log'")
            end

            local test_command = "raco cover -f raw -d '" .. coverage_dir .. "' " .. table.concat(test_files, " ") .. " 2>&1; echo \"exit_code: $?\";"
            local handle = io.popen(test_command)

            if not handle then
                error("Failed to execute racket raco command: " .. test_command)
            end

            local output = handle:read("*a")
            handle:close()

            local exit_code = tonumber(output:match("\nexit_code: (%d+)%s*$"))

            if exit_code ~= 0 then
                print("Running tests failed:\n" .. output)
                return
            end

            print("Running coverage complete")

            local convert_output = rktl_to_json_str(coverage_dir .. "/coverage.rktl")
            util.write_to_file(coverage_dir .. "/uncovered.json", convert_output)
            uncovered = construct_uncovered(convert_output)
            if vim.bo.filetype == "racket" then
                set_show_uncovered(true)
            end

            local fail_pattern = "^(.+):(%d+): (.+)$"
            local fail_match = string.match(output, fail_pattern)

            if fail_match == nil then
                print("All tests succeeded")
                return
            end

            print("Tests failed:")
            print(output)
        end,
        { nargs = '+' }
    )
end

---Sets up the plugin with opts
---@param opts table
---@return nil
function M.setup(opts)
    util = require("racket-cover.util")

    local default_opts = {
        highlight_uncovered = true,
        uncovered_diagnostic = true,
        coverage_dir = "/tmp/racket-cover",
        highlight_group = { fg = "#ff0000", undercurl = true }
    }

    opts = util.merge_tables(opts, default_opts)

    do_highlight_uncovered = opts.highlight_uncovered
    do_diagnostic_uncovered = opts.highlight_uncovered

    coverage_dir = util.path_join(opts.coverage_dir, string.gsub(vim.fn.getcwd(), "/", "%%"))

    uncovered_hl_space = vim.api.nvim_create_namespace("racketUncovered")

    vim.api.nvim_set_hl(0, "racketUncovered", opts.highlight_group)

    racket_cover_aug = vim.api.nvim_create_augroup("racketCover", { clear = true })

    create_user_commands()
end

return M
